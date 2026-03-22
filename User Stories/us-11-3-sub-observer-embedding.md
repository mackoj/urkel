# US-11.3: Sub-Observer Embedding for Composed Machines

**Supersedes:** US-11.2 (Orchestrator Actor Emitter)  
**Depends on:** US-11.1 (Fork Operator & Composition AST)  
**Status:** Proposed

---

## 1. Objective

Replace the generated actor orchestrator model (US-11.2) with **sub-observer embedding**: for every machine that uses `@compose`, the parent `XObserver<State>` directly carries the composed sub-machine's state inside itself. The parent machine becomes its own coordinator. No separate actor type is generated.

Simultaneously, clean up the non-composed generated file: remove the unused `XRuntimeContext` struct, fix formatting, and add precise ownership doc-comments that explain the `~Copyable`/`~Escapable` model.

---

## 2. Context

US-11.2 described a `public actor ScaleOrchestrator` that would hold `private var scaleState: ScaleState` and `private var bleState: BLEState?`. This design is correct in intent but unimplementable under Swift 6.2:

- `ScaleState: ~Copyable` cannot be stored as a class/actor stored property and consumed inside actor methods. Consuming a reference-type stored property is not supported by the language.
- Every workaround (class boxes, unsafe pointers, Optional slots with `consume`) either fails to compile or introduces unbounded unsafety.

The fix is structural: instead of an actor *holding* two machines, the parent observer *carries* the sub-observer inside itself as a `~Copyable` stored property on a value type. Value-type fields *can* be partially consumed in a locally owned context, which is exactly how `switch consume self` already works throughout the generated code today.

---

## 3. Acceptance Criteria

### 3.1 Non-composed machines (clean-up only)

- **Given** a `.urkel` file with no `@compose`.
- **When** the emitter runs.
- **Then** the generated file does **not** contain `XRuntimeContext`.
- **And** `withXxx` inspection methods use `guard case let … = self` (not exhaustive switch).
- **And** the `fromRuntime` extension has consistent 4-space indentation.
- **And** `XObserver<State>` has a doc-comment explaining `consuming` ownership semantics.
- **And** `XState` has a usage doc-comment showing the `var state = …; state = try await state.start()` pattern.

### 3.2 Composed machines — observer carries the sub-observer

- **Given** an AST for `Scale` that declares `@compose BLE`.
- **When** emitted.
- **Then** `ScaleObserver<State>` has:
  - `var _bleState: BLEState?` — initially `nil`, set at the fork transition.
  - `let _makeBLE: @Sendable () -> BLEObserver<BLEMachine.Off>` — the factory.
- **And** both fields are present on **every** `ScaleObserver<State>` regardless of the current state.
- **And** the emitter generates **no** `ScaleOrchestrator` type.
- **And** the emitter generates **no** `ScaleStateBox` or `BLEStateBox` class.

### 3.3 Fork transition spawns the sub-observer

- **Given** a transition annotated `=> BLE.init` (e.g. `WakingUp -> hardwareReady -> Tare => BLE.init`).
- **When** the emitter generates `ScaleObserver<WakingUp>.hardwareReady()`.
- **Then** the generated body:
  1. Calls `_hardwareReady(internalContext)`.
  2. Constructs `BLEState(_makeBLE())` and passes it as `_bleState:` in the returned `ScaleObserver<Tare>`.

### 3.4 Non-fork transitions carry the sub-observer forward

- **Given** any Scale transition that does **not** carry `=> BLE.init`.
- **When** emitted.
- **Then** the returned observer is constructed with `_bleState: _bleState` (passing the current slot through).
- **And** ownership is transferred correctly — `self._bleState` is consumed and forwarded in the same `consuming func`.

### 3.5 BLE-forwarding methods on the combined state

- **Given** the `BLE` machine has a transition `Off -> powerOn -> WakingRadio`.
- **When** the `Scale` machine is emitted.
- **Then** `ScaleState` gains a `consuming func blePowerOn() async throws -> ScaleState`.
- **And** the generated body:
  - Switches over every case of `ScaleState` using `switch consume self`.
  - For cases where `_bleState` is set (all states from `Tare` onwards), performs partial consumption: `consume obs._bleState`, transitions BLE, and stores the result back with `obs._bleState = …`.
  - For cases where BLE is not yet spawned (`Off`, `WakingUp`) or no longer relevant (`PowerDown`), passes the observer through unchanged.
- **And** `ScaleState` has one such method for **every** event defined in the `BLE` machine's `@transitions` block.
- **And** every BLE-forwarding method is prefixed with the composed machine name in camel case: `ble` + EventName (e.g. `blePowerOn`, `bleDeviceDiscovered(device:)`).

### 3.6 Client factory signature includes the sub-machine factory

- **Given** `scale.urkel` with `@compose BLE` and `@factory makeScale()`.
- **When** emitted.
- **Then** `ScaleClient.makeScale` has signature:
  ```swift
  makeScale: @Sendable (makeBLE: @Sendable () -> BLEObserver<BLEMachine.Off>) -> ScaleObserver<ScaleMachine.Off>
  ```
- **And** `ScaleClient.fromRuntime(_ runtime: ScaleClientRuntime)` passes `runtime.initialBLEFactory` as the `_makeBLE` closure when constructing the initial observer.

### 3.7 `~Escapable` opt-in (additive, non-breaking)

- **Given** a `.urkel` file or `urkel-config.json` that sets `nonescapable: true`.
- **When** emitted.
- **Then** `XObserver<State>` and `XState` carry `: ~Copyable, ~Escapable` instead of just `: ~Copyable`.
- **And** the generated doc-comment explains that `~Escapable` enforces the structured-task pattern and prevents storing the state in an actor.
- **Given** no `nonescapable` annotation.
- **When** emitted.
- **Then** the output is `~Copyable` only — existing code compiles without change.

### 3.8 Call-site correctness

- **Given** the `BluetoohScale` example regenerated with the new emitter.
- **When** `swift build` is run in `Examples/BluetoohScale`.
- **Then** the build succeeds with zero errors and zero warnings.
- **And** all existing `BluetoohScaleTests` pass.
- **And** the `ScaleOrchestrator` type no longer exists.
- **And** `BluetoohScale.swift`'s `makeOrchestrator()` helper is removed and replaced with documentation showing the single-variable usage pattern.

### 3.9 Non-regression

- **Given** `Examples/FolderWatch` and `Examples/BluetoohBlender` (non-composed).
- **When** regenerated with the new emitter.
- **Then** all their tests continue to pass.
- **And** the generated files no longer contain `XRuntimeContext`.

---

## 4. Implementation Details

### 4.1 `SwiftCodeEmitter` changes

#### Remove `emitRuntimeContext()`
The `XRuntimeContext` struct has been dead code since the `fromRuntime` builder was introduced. Delete `emitRuntimeContext()` and its call site in `emitMachineClient()`.

#### Update `emitObserver()` for composed machines
Add a guard: if `ast.composedMachines` is non-empty, emit the additional fields:

```
var _<composedName>State: <ComposedName>State?
let _make<ComposedName>: @Sendable () -> <ComposedName>Observer<<ComposedName>Machine.<InitState>>
```

Both fields must be added to the struct's `init` parameters and stored properties, AND forwarded in every `emitTransition()` return constructor.

#### Update `emitTransition()` to carry sub-observers
For every return constructor in a non-fork transition, append:
```
_<composedName>State: _<composedName>State,
_make<ComposedName>: _make<ComposedName>,
```

For the fork transition (where `TransitionNode.spawnedMachine == composedName`), replace the slot assignment:
```swift
_<composedName>State: <ComposedName>State(_make<ComposedName>()),
```

#### Add `emitComposedForwardingMethods()`
New function called from `emitCombinedState()` when `ast.composedMachines` is non-empty.

For each event in the composed machine:
1. Emit `public consuming func <composedName><EventName>(<params>) async throws -> Self`.
2. Emit a `switch consume self` over all cases of the parent combined state.
3. For each case where BLE is present (states from the fork's target state onwards), emit the partial-consumption pattern:
   ```swift
   case var .<stateName>(obs):
       var sub = consume obs._<composedName>State
       obs._<composedName>State = .none
       if let s = consume sub {
           obs._<composedName>State = try await s.<eventName>(<args>)
       }
       return .<stateName>(obs)
   ```
4. For pre-fork and terminal states, emit pass-through.

#### Update `emitClientRuntime()` for composed machines
Add `initialBLEFactory` (or generically, `initial<ComposedName>Factory`) to `XClientRuntime`.
Update `fromRuntime` to pass this factory as `_make<ComposedName>:` when constructing the initial observer.

#### Remove `emitOrchestrator()`
Delete the function and all call sites.

#### `~Escapable` opt-in
Add a `nonescapable: Bool` property to `UrkelConfig`. When `true`, change the observer/state conformance emission from `: ~Copyable` to `: ~Copyable, ~Escapable`.

### 4.2 `UrkelConfig` changes

Add:
```swift
/// When true, the emitted observer and combined-state types conform to both
/// `~Copyable` and `~Escapable`, enforcing the structured-task usage pattern.
public var nonescapable: Bool = false
```

Support the `"nonescapable": true` key in `urkel-config.json`.

### 4.3 `BluetoohScale` example updates

- Regenerate `ScaleFSMClient.swift` and `BLEFSMClient.swift`.
- Remove `ScaleOrchestrator` from the generated file (it will no longer be emitted).
- Remove `BluetoohScaleSystem.makeOrchestrator()` from `BluetoohScale.swift`.
- Update `BluetoohScaleTests.swift`:
  - Replace the `orchestratorSpawnsBLE` test with a test that drives the single `ScaleState` variable through the fork and asserts `state.withTare { $0._bleState != nil }`.
  - Add a test that drives BLE events through `blePowerOn()`, `bleDeviceDiscovered(device:)`, etc. via the same `state` variable.
- Update `README.md` to show the single-variable call site.

---

## 5. Testing Strategy

### 5.1 Emitter unit tests (`UrkelEmitterTests`)

| Test | Input | Assert |
|---|---|---|
| `testNoComposedMachineDoesNotEmitSubObserverSlot` | Machine with no `@compose` | Output does not contain `_bleState` |
| `testNoComposedMachineDoesNotEmitOrchestrator` | Machine with no `@compose` | Output does not contain `actor … Orchestrator` |
| `testNoComposedMachineDoesNotEmitRuntimeContext` | Any machine | Output does not contain `RuntimeContext` |
| `testComposedMachineHasSubObserverSlotInObserver` | Machine with `@compose BLE` | Output contains `var _bleState: BLEState?` and `let _makeBLE:` |
| `testForkTransitionSpawnsBLE` | Transition `A -> evt -> B => BLE.init` | Generated `evt()` body contains `BLEState(_makeBLE())` |
| `testNonForkTransitionCarriesBLEForward` | Any non-fork transition | Generated body contains `_bleState: _bleState,` |
| `testBLEForwardingMethodsGeneratedOnCombinedState` | Machine with `@compose BLE` | `ScaleState` contains `blePowerOn()` etc. |
| `testBLEForwardingPassesThroughPreForkStates` | Same | Pre-fork cases return `.<state>(obs)` unchanged |
| `testBLEForwardingConsumesSlotInPostForkStates` | Same | Post-fork cases contain `consume obs._bleState` |
| `testNonescapableConfigEmitsCorrectConformance` | Config with `nonescapable: true` | Output contains `: ~Copyable, ~Escapable` |
| `testDefaultConfigEmitsOnlyCopyable` | Config with default | Output contains `: ~Copyable` not `~Escapable` |
| `testClientRuntimeHasBLEFactory` | Machine with `@compose BLE` | `XClientRuntime` struct contains `initial<Name>Factory` |

### 5.2 Integration / example tests

| Test | Description |
|---|---|
| `BluetoohScale.testScaleFlowMeasuresMetricsAndPowersDown` | Unchanged — still drives `ScaleState` var |
| `BluetoohScale.testBLEEmbeddedAfterFork` | New — asserts BLE slot non-nil after `hardwareReady` |
| `BluetoohScale.testBLEAdvancesViaForwardingMethods` | New — drives full BLE flow via `state.blePowerOn()` etc. |
| `BluetoohScale.testNoOrchestrator` | New — compilation test: `ScaleOrchestrator` type does not exist |
| `FolderWatch.*` | All existing tests pass unchanged |
| `BluetoohBlender.*` | All existing tests pass unchanged |

### 5.3 Snapshot / golden-file tests

Add snapshot tests that fix the exact text output for:
- A minimal composed machine (2 states, 1 fork) — `ScaleObserver` struct, one BLE-forwarding method.
- The non-composed FolderWatch baseline — full file (regression guard against reintroducing dead code).

---

## 6. What Does NOT Change

- `XObserver<State>` and `XState` API for non-composed machines — identical to today.
- Developer-written `XClient+Live.swift` files — only the factory signature changes.
- `XClientRuntime` struct shape for non-composed machines.
- The `@compose` grammar (US-11.1) and AST nodes.
- `FolderWatchClient+Generated.swift` content (beyond formatting and dead-code removal).

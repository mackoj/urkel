# US-11.4: `@compose` — SubFSM Actor Bridge Emitter

**Supersedes:** US-11.3 (Sub-Observer Embedding), US-11.2 (Orchestrator Actor Emitter)  
**Depends on:** US-11.1 (Fork Operator & Composition AST) — `@compose` keyword and `composedMachines` AST field only; the `=>` fork-transition operator is **not required** by this story  
**Status:** Proposed  
**Reference implementation:** `Examples/MFSM/Sources/MultipleFSM/MultipleFSM.swift`

---

## 1. Objective

When a machine declares `@compose`, the emitter generates one `private actor SubFSM<Name>` per composed machine alongside the parent `makeLive()` extension. Each actor owns its sub-machine as a noncopyable `Phase` enum, exposes `start()`, `stop()`, and `error(_:)` async methods, and is captured by the parent's three `@Sendable` transition closures. No modifications to the parent machine's `~Copyable` observer struct are required.

---

## 2. Context

US-11.3 proposed embedding sub-machine state directly inside the parent `~Copyable` value type, relying on `switch consume self` within the parent's consuming methods. This is correct in theory but unimplementable in Swift 6.3:

- Actor stored properties are exposed through synthesised `_read`/`_modify` coroutine accessors. The `consume` operator requires **direct storage**, so `switch consume phase` on an actor property is rejected with *"consume can only be used to partially consume storage"*.
- Storing a `~Copyable` machine in a class or actor property and then extracting it via normal assignment is also rejected — the only escape is unsafe pointer operations.

US-11.4 resolves this by keeping the parent observer untouched and placing each sub-machine inside its own dedicated actor. Actors are `Sendable`, so they can be safely captured across the three `@Sendable` closures (`_start`, `_errorError`, `_stop`) in the parent machine. The `~Copyable` problem is contained entirely inside the actor, where `withUnsafeMutablePointer` + `ptr.move()` is used once to transfer ownership from the actor's storage into a local variable that the compiler *can* `consume`.

---

## 3. Acceptance Criteria

### 3.1 No `@compose` — no change

- **Given** a `.urkel` file with no `@compose` directive.
- **When** the emitter runs.
- **Then** the generated output is identical to the current non-composed output — no `SubFSM` actor, no `takePhase`, no wiring in `makeLive()`.

### 3.2 `@compose` emits one actor per composed machine

- **Given** a `.urkel` file with `@compose SomeFeature1, SomeFeature2`.
- **When** the emitter runs.
- **Then** the generated file contains:
  - `private actor SubFSMSomeFeature1 { … }`
  - `private actor SubFSMSomeFeature2 { … }`
- **And** each actor has a `private enum Phase: ~Copyable` with three cases:
  - `.idle(SomeFeature1Machine<SomeFeature1StateIdle>)`
  - `.running(SomeFeature1Machine<SomeFeature1StateRunning>)`
  - `.dead`
- **And** each actor has a `private func takePhase() -> Phase` implemented with `withUnsafeMutablePointer`.

### 3.3 `takePhase()` correctly moves out of actor storage

- **Given** a generated `SubFSMSomeFeature1`.
- **When** `takePhase()` is called.
- **Then** `phase` is atomically replaced with `.dead` and the previous value is returned as a local owned `Phase`.
- **And** the body uses `withUnsafeMutablePointer(to: &phase) { ptr in let taken = ptr.move(); ptr.initialize(to: .dead); return taken }`.

### 3.4 Actor transition methods use `let current = takePhase(); switch consume current`

- **Given** the generated actor.
- **When** any of `start()`, `stop()`, or `error(_:)` is called.
- **Then** the pattern is:
  ```swift
  let current = takePhase()
  switch consume current {
  case .idle(let machine): …
  case .running(let machine): …
  case .dead: break
  }
  ```
- **And** `.dead` is used as the sentinel for the window between `takePhase()` and the `await` completing.
- **And** errors thrown by the sub-machine transition leave `phase` as `.dead` (the sub-machine is considered finished).

### 3.5 `start()` transitions `.idle → .running`

- **Given** the actor in `.idle` phase.
- **When** `start()` is called.
- **Then** `machine.start()` is awaited and the result is stored as `.running(…)`.
- **And** if `machine.start()` throws, `phase` remains `.dead` and the error is re-thrown.
- **Given** the actor is already `.running`.
- **When** `start()` is called again.
- **Then** the phase is restored to `.running(machine)` unchanged (idempotent, no error).

### 3.6 `stop()` and `error(_:)` consume `.running → .dead`

- **Given** the actor in `.running` phase.
- **When** `stop()` or `error(_:)` is called.
- **Then** the appropriate consuming transition is awaited and `phase` is set to `.dead`.
- **And** errors during teardown are swallowed (sub-machine teardown must not block parent teardown).
- **Given** the actor in `.idle` phase when `stop()` is called.
- **Then** `phase` is restored to `.idle(machine)` unchanged.

### 3.7 Parent `makeLive()` creates actors and captures them in closures

- **Given** a generated `MainFSMClient.makeLive()`.
- **Then** it contains:
  ```swift
  let feature1 = SubFSMSomeFeature1(SomeFeature1Client.makeLive().makeSomeFeature1())
  let feature2 = SubFSMSomeFeature2(SomeFeature2Client.makeLive().makeSomeFeature2())
  ```
- **And** `_start` calls `try await feature1.start()` and `try await feature2.start()`.
- **And** `_errorError` calls `try await feature1.error(error)` and `try await feature2.error(error)`.
- **And** `_stop` calls `try await feature1.stop()` and `try await feature2.stop()`.
- **And** the start order follows declaration order in `@compose`.

### 3.8 Dependency injection — composed machines accept injected clients

- **Given** `MainFSMClient.fromRuntime(_ runtime: MainFSMClientRuntime)`.
- **When** the runtime is used to construct `makeLive()`.
- **Then** each composed machine's client is passed as a parameter to `fromRuntime` so that test doubles can be injected without modifying `makeLive()`.

### 3.9 Build succeeds end-to-end

- **Given** the `Examples/MFSM` package with `mfsm.urkel` declaring `@compose SomeFeature1, SomeFeature2`.
- **When** `swift build` is run.
- **Then** the build succeeds with zero errors.
- **And** the `MultipleFSMTests` suite passes.

### 3.10 Generated doc-comment explains the unsafe workaround

- **Given** the generated actor.
- **Then** `takePhase()` carries a doc-comment explaining:
  1. Why `consume` cannot be used directly on actor stored properties in Swift 6.3.
  2. That `withUnsafeMutablePointer` + `ptr.move()` is the intentional workaround.
  3. That this can be revisited when Swift adds a consuming accessor for actor stored properties.

---

## 4. Implementation Details

### 4.1 Parser / AST (US-11.1 already covers this)

No new grammar changes. The `@compose Name1, Name2` syntax and `MachineAST.composedMachines: [String]` from US-11.1 are sufficient. The `=>` fork-transition operator is **not emitted** by this story.

### 4.2 `SwiftCodeEmitter` changes

#### New function: `emitSubFSMActor(for composedName: String, parentAST: MachineAST)`

Emits the `private actor SubFSM<Name>` type. Logic:

1. Resolve the composed machine's init state and running state from the composed machine's own AST (looked up by name from the workspace).
2. Emit `Phase: ~Copyable` enum with `.idle(…)`, `.running(…)`, `.dead`.
3. Emit `private var phase: Phase`.
4. Emit `init(_ machine: consuming …)` that sets `phase = .idle(consume machine)`.
5. Emit `private func takePhase() -> Phase` using the `withUnsafeMutablePointer` pattern.
6. Emit `func start()`, `func stop()`, `func error(_:)` using `let current = takePhase(); switch consume current { … }`.

#### Update `emitMakeLive()` for composed machines

When `ast.composedMachines` is non-empty:

1. Before the `return Self { … }` block, emit one `let feature<N> = SubFSM<Name>(…Client.makeLive().make<Name>())` per composed machine.
2. Inside `_start`, append `try await feature<N>.start()` for each, in declaration order.
3. Inside `_errorError`, append `try await feature<N>.error(error)` for each.
4. Inside `_stop`, append `try await feature<N>.stop()` for each.

#### No changes to `emitObserver()` or `emitCombinedState()`

The parent observer struct and its `~Copyable` machinery are untouched.

### 4.3 Handling machines with no explicit `stop` or `error` transition on the composed machine

If a composed machine has no `error` transition, the `error(_:)` method on the actor should fall back to calling `stop()`. Emit a note in the doc-comment.

### 4.4 `withUnsafeMutablePointer` overload requirements

Requires the `withUnsafeMutablePointer<T: ~Copyable, Result: ~Copyable>` overload from SE-0437 (available in Swift 6.0+). Add a `#if swift(>=6.0)` guard and emit a compile-time error for earlier versions.

---

## 5. Testing Strategy

### 5.1 Emitter unit tests

| Test | Input | Assert |
|---|---|---|
| `testNoComposeEmitsNoSubFSMActor` | Machine with no `@compose` | Output does not contain `actor SubFSM` |
| `testComposeEmitsOneActorPerMachine` | `@compose A, B` | Output contains `actor SubFSMA` and `actor SubFSMB` |
| `testPhaseEnumHasThreeCases` | Any composed machine | Output contains `.idle(…)`, `.running(…)`, `.dead` |
| `testTakePhaseUsesUnsafePointer` | Any composed machine | Output contains `withUnsafeMutablePointer(to: &phase)` and `ptr.move()` |
| `testStartMethodUsesLetCurrentPattern` | Any composed machine | Output contains `let current = takePhase()` and `switch consume current` |
| `testMakeLiveCreatesActorBeforeReturn` | Composed machine | Output contains `let feature1 = SubFSM…` before `return Self` |
| `testMakeLiveWiresAllThreeHooks` | Composed machine | `_start` contains `feature1.start()`, `_errorError` contains `feature1.error`, `_stop` contains `feature1.stop()` |
| `testStartOrderMatchesDeclarationOrder` | `@compose A, B` | `feature1.start()` appears before `feature2.start()` in `_start` body |
| `testDocCommentExplainsUnsafeWorkaround` | Any composed machine | `takePhase()` output contains a comment referencing Swift actor accessor limitation |

### 5.2 Integration test — MFSM example

- `swift build` on `Examples/MFSM` succeeds.
- A test that creates `MainFSMClient.makeLive()`, calls `makeMainFSM()`, drives it through `start()` → `stop()`, and asserts `SomeFeature1Machine` lifecycle print statements appeared in the expected order.

### 5.3 Non-regression

- `FolderWatch` and `BluetoohBlender` (non-composed) build and their tests pass unchanged.

---

## 6. What Does NOT Change

- The parent `~Copyable` observer struct and its state machine API.
- The `XClientRuntime` struct for non-composed machines.
- The `@factory` / `fromRuntime` pattern for non-composed machines.
- US-11.1 AST/parser work (reused as-is).
- The `=>` fork-transition operator (left for a future story if needed).

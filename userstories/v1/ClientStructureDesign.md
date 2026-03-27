# Urkel Client Structure Design

**Status:** Revised — v2 supersedes the box/orchestrator proposal  
**Context:** Swift 6.2, `-swift-version 6`, `~Copyable` + `~Escapable` ownership

---

## Table of Contents

1. [The Building Blocks](#1-the-building-blocks)
2. [Current Model — Single Machine (FolderWatch)](#2-current-model--single-machine-folderwatch)
3. [Current Model — Composed Machine (BluetoohScale)](#3-current-model--composed-machine-bluetoohscale)
4. [Pain Points in the Current Composed Model](#4-pain-points-in-the-current-composed-model)
5. [Why the Box/Orchestrator Approach Fails](#5-why-the-boxorchestrator-approach-fails)
6. [Proposed Model v2 — Sub-Observer Embedding](#6-proposed-model-v2--sub-observer-embedding)
7. [What `~Escapable` Adds](#7-what-escapable-adds)
8. [Proposed Structure Walkthrough](#8-proposed-structure-walkthrough)
9. [Urkel Language Implications](#9-urkel-language-implications)
10. [Migration Path](#10-migration-path)
11. [Open Questions](#11-open-questions)

---

## 1. The Building Blocks

Every generated client is assembled from four layers:

| Layer | Type | Description |
|---|---|---|
| **Observer** | `struct XObserver<State>: ~Copyable` | Noncopyable, typestate-parameterised. Holds the `Context` + closures for each transition. Consuming a transition moves ownership to the returned observer. |
| **Combined State** | `enum XState: ~Copyable` | Erases the typestate parameter so state can be stored in a single `var`. Transition methods call down to the typed observer and re-wrap the result. |
| **Client** | `struct XClient: Sendable` | Dependency-injection entry point. Contains factory closures (`makeX()`) that produce the initial typed observer. Conforms to `DependencyKey`. |
| **Runtime** | `struct XClientRuntime` + `XRuntimeStream` | Internal plumbing wired by the developer's handwritten `XRuntimeHandlers`. Not part of the public API. |

---

## 2. Current Model — Single Machine (FolderWatch)

FolderWatch has three states (`Idle → Running → Stopped`) and **no composition**.

```
┌──────────────────────────────────────────────────────┐
│ Generated (FolderWatchClient+Generated.swift)        │
│                                                      │
│  FolderWatchObserver<State>  (~Copyable)             │
│    .start()  →  FolderWatchObserver<Running>         │
│    .stop()   →  FolderWatchObserver<Stopped>         │
│                                                      │
│  FolderWatchState  (~Copyable)                       │
│    .idle(FolderWatchObserver<Idle>)                  │
│    .running(FolderWatchObserver<Running>)            │
│    .stopped(FolderWatchObserver<Stopped>)            │
│    .start() / .stop()   (consuming wrappers)         │
│                                                      │
│  FolderWatchClient  (Sendable, DependencyKey)        │
│    makeObserver: (URL, Int) → Observer<Idle>         │
└──────────────────────────────────────────────────────┘
           │
           │  .fromRuntime(FolderWatchClientRuntime)
           ▼
┌──────────────────────────────────────────────────────┐
│ Developer writes (FolderWatchClient+Live.swift etc.) │
│   FolderWatchRuntimeHandlers                         │
│     .start: (Context) async throws → Context         │
│     .stop:  (Context) async throws → Context         │
└──────────────────────────────────────────────────────┘
```

**Usage at call site (e.g. a TCA reducer):**

```swift
@Dependency(\.folderWatch) var client
// Somewhere in a Task or Effect:
var state = FolderWatchState(client.makeObserver(url, debounce))
state = try await state.start()
// later:
state = try await state.stop()
```

**Key properties:**
- One `var state: XState` drives the whole lifecycle.
- `state` is `~Copyable`, so accidental copies are compile errors.
- Transitions are clear, linear, and impossible to misorder at compile time.
- No orchestrator needed — the `XState` enum _is_ the coordinator.

---

## 3. Current Model — Composed Machine (BluetoohScale)

`scale.urkel` declares `@compose BLE`. The hardwareReady transition contains `=> BLE.init`, meaning BLE is spawned as a side-effect mid-flow.

### What is generated today

```
ScaleFSMClient.swift
  ScaleObserver<State>     — noncopyable typestate wrapper (same as FolderWatch)
  ScaleState               — noncopyable combined enum (same as FolderWatch)
  ScaleClient              — dependency client (same as FolderWatch)
  ScaleOrchestrator        — NEW: actor that owns ScaleState + BLEState lifecycle  ← PROBLEM AREA

BLEFSMClient.swift
  BLEObserver<State>       — noncopyable typestate wrapper
  BLEState                 — noncopyable combined enum
  BLEClient                — dependency client
```

### The current `ScaleOrchestrator` (workaround)

```swift
public actor ScaleOrchestrator {
    private enum Phase { case off, wakingUp, tare, ... }  // mirrors ScaleState but erases all types
    private var phase: Phase                               // loses noncopyable ownership guarantees
    private var bleState: BLEState?                        // Optional — nil until spawned
    private let makeBLEState: @Sendable () -> BLEState

    public func footTap() async throws { ... }   // plain if-phase guards
    public func hardwareReady() async throws { ... }
    // ...
}
```

The `Phase` enum duplicates all the information already present in `ScaleState`.  
There is **no typed guarantee** that you cannot call `weightLocked` while in the `off` phase — it just silently no-ops.

---

## 4. Pain Points in the Current Composed Model

### 4.1 `ScaleState` is generated but never stored

The orchestrator drops the noncopyable `ScaleState` on the floor in `init`, converting it to a `Phase` string.  All the typestate guarantees the generator went to great effort to produce are immediately discarded.

### 4.2 Storing `~Copyable` in an actor is hard under Swift 6.2

The intended design was:

```swift
public actor ScaleOrchestrator {
    private var scaleState: ScaleState    // noncopyable — stored in actor ← Swift 6.2 refuses this pattern
    private var bleState: BLEState?
}
```

Swift 6.2 does not allow consuming a stored `~Copyable` property inside an actor method:

```
error: 'scaleState' is borrowed and cannot be consumed
error: field 'scaleState' consumed but not reinitialized during access
```

The ownership model requires that after a `consume`, the variable must be re-assigned before the function returns — but async throws functions with early-return paths make this near-impossible with a plain stored property.

### 4.3 The orchestrator API is untyped

```swift
orchestrator.footTap()       // valid in any phase — silently ignored if wrong
orchestrator.weightLocked()  // valid in any phase — silently ignored if wrong
```

Compare the single-machine model where calling `.start()` on a `running` observer is a type error.

### 4.4 Developer code wires two independent clients manually

```swift
public func makeOrchestrator() -> ScaleOrchestrator {
    ScaleOrchestrator(
        initialState: ScaleState(self.scaleClient.makeScale()),
        makeBLEState: { BLEState(self.bleClient.makeBLE()) }
    )
}
```

The developer has to know that `makeBLE` should not be called eagerly, but is instead passed as a lazy factory. This is undocumented, invisible, and breaks the single `@factory` declaration model.

---

## 5. Why the Box/Orchestrator Approach Fails

An earlier revision of this document proposed wrapping `XState` in a `final class ScaleStateBox` and storing it in a separate actor. This fails at the language level:

```swift
// DOES NOT COMPILE
final class ScaleStateBox: @unchecked Sendable {
    var value: ScaleState  // ~Copyable value inside a class
}

func transition() async throws {
    scaleBox.value = try await scaleBox.value.footTap()
    // error: cannot consume noncopyable stored property of a class
}
```

Swift 6.2 does not allow consuming a stored property of a reference type (class or actor). Class properties can only be borrowed (read-only). Between `consume` and re-assignment lies an `await` — and actor re-entrancy means another call could arrive and touch uninitialized memory during that window.

Every attempted workaround (Optional slots, unsafe pointers, Mutex, nonisolated storage) either fails to compile, introduces unsafety that cannot be bounded, or defeats the `~Copyable` guarantee entirely.

**Root cause:** The separate actor orchestrator is fighting against ownership. The `XObserver<State>` is designed to be *moved*, not *stored and mutated remotely*. Putting it in a long-lived actor creates a fundamental mismatch.

---

## 6. Proposed Model v2 — Sub-Observer Embedding

**Key insight:** Instead of a separate orchestrator that *holds* two machines, the parent observer should *carry* its composed sub-observer directly inside itself. The parent machine **is** the orchestrator.

### Single machine (no change)

For machines without `@compose`, the model stays exactly as-is. `XObserver<State>: ~Copyable` holds a context and closures. Transitions consume the observer and return a new one. `XState: ~Copyable` wraps all typed observers for storage in a local `var`.

### Composed machine — new shape

For `scale.urkel` with `@compose BLE`, the generator adds a sub-observer slot to `ScaleObserver<State>`:

```swift
// Generated
public struct ScaleObserver<State>: ~Copyable {
    var internalContext: ScaleContext

    // ── Composed sub-observer ───────────────────────────────────────
    // nil before the `=> BLE.init` fork fires; non-nil afterwards.
    // Ownership moves with every Scale transition automatically.
    var _bleState: BLEState?    // BLEState: ~Copyable

    // ── BLE factory (used once, at the fork) ─────────────────────────
    let _makeBLE: @Sendable () -> BLEObserver<BLEMachine.Off>

    // ── Scale transition closures (unchanged) ─────────────────────────
    let _footTap:      @Sendable (ScaleContext) async throws -> ScaleContext
    let _hardwareReady: @Sendable (ScaleContext) async throws -> ScaleContext
    // ...
}
```

### Fork transition — BLE is spawned here

The transition that carries `=> BLE.init` creates the sub-observer and embeds it:

```swift
extension ScaleObserver where State == ScaleMachine.WakingUp {
    public consuming func hardwareReady() async throws -> ScaleObserver<ScaleMachine.Tare> {
        let nextCtx = try await self._hardwareReady(self.internalContext)
        // Spawn BLE: the factory runs once, right here.
        let initialBLE = BLEState(self._makeBLE())
        return ScaleObserver<ScaleMachine.Tare>(
            internalContext: nextCtx,
            _bleState: initialBLE,       // BLE now lives inside Scale ✓
            _makeBLE: self._makeBLE,
            _footTap: self._footTap,
            // ... carry all closures
        )
    }
}
```

### Subsequent Scale transitions carry BLE forward automatically

The sub-observer moves with its parent — no extra developer wiring:

```swift
extension ScaleObserver where State == ScaleMachine.Tare {
    public consuming func zeroAchieved() async throws -> ScaleObserver<ScaleMachine.Weighing> {
        let nextCtx = try await self._zeroAchieved(self.internalContext)
        return ScaleObserver<ScaleMachine.Weighing>(
            internalContext: nextCtx,
            _bleState: self._bleState,   // moves with parent, zero cost ✓
            _makeBLE: self._makeBLE,
            _footTap: self._footTap,
            // ...
        )
    }
}
```

`~Copyable` on `ScaleObserver` ensures ownership: the BLE sub-observer cannot end up in two places at once, because Scale itself cannot be copied.

### BLE event forwarding via the combined state

`ScaleState`'s transition methods are extended with BLE-forwarding overloads. These are only callable when BLE is actually present (enforced via the Optional slot pattern):

```swift
extension ScaleState {
    // Generated for every BLE transition — forwards to embedded BLE machine
    public consuming func blePowerOn() async throws -> ScaleState {
        switch consume self {
        case var .tare(obs):
            // Partial consumption: take BLE out of obs, transition it, put it back
            var ble = consume obs._bleState
            obs._bleState = .none
            if let b = consume ble {
                obs._bleState = try await b.powerOn()
            }
            return .tare(obs)
        case var .weighing(obs):
            var ble = consume obs._bleState
            obs._bleState = .none
            if let b = consume ble { obs._bleState = try await b.powerOn() }
            return .weighing(obs)
        // … for every state where BLE can be present
        case let .off(obs):        return .off(obs)
        case let .wakingUp(obs):   return .wakingUp(obs)
        case let .powerDown(obs):  return .powerDown(obs)
        }
    }

    // … bleScanTimeout(), bleDeviceDiscovered(device:), etc.
}
```

> **Note on partial consumption:** `consume obs._bleState` where `obs` is a **locally owned** `~Copyable` struct (not a class property) is valid in Swift 6.2. Ownership proposals explicitly support consuming fields of locally owned noncopyable values, provided the field is reinitialized before the value is used again.

### Usage at the call site

The composed machine is now driven through a single `var state: ScaleState`, just like a non-composed machine:

```swift
var state = ScaleState(client.makeScale())   // BLE slot is nil here

state = try await state.footTap()
state = try await state.hardwareReady()      // BLE spawned; slot is now non-nil

// Both machines advance through the same variable:
state = try await state.blePowerOn()         // BLE event
state = try await state.zeroAchieved()       // Scale event
state = try await state.bleRadioReady()      // BLE event
state = try await state.bleDeviceDiscovered(device: found)
state = try await state.bleConnectionEstablished()
state = try await state.weightLocked(weight: 79.6)
// …

// The Scale "emit to BLE" transition:
// syncData advances Scale to PowerDown AND simultaneously forwards to BLE.startSync
state = try await state.syncData(payload: combined)
```

No separate orchestrator type. No actor. No boxes. The state machine IS its own coordinator.

---

## 7. What `~Escapable` Adds

`~Escapable` (SE-0426 / SE-0446, available in Swift 6.2) is a separate constraint from `~Copyable`:

| Constraint | What it prevents |
|---|---|
| `~Copyable` | Creating a second copy of the value |
| `~Escapable` | Storing the value in a location that outlives the current scope |

A type marked `~Escapable` **cannot**:
- Be stored as a property in a class, struct, or actor
- Be captured by a `@Sendable` closure
- Be returned from a function without explicit lifetime annotations

A type marked `~Escapable` **can**:
- Be held in a local `var` within an `async func` or a `Task` closure
- Be passed to consuming functions
- Be pattern-matched in a `switch`

### What this means for Urkel observers

If `ScaleObserver<State>: ~Copyable, ~Escapable`, the compiler enforces a structured concurrency pattern:

```swift
// ✅ Valid — state lives inside the Task's stack frame
Task {
    var state = ScaleState(client.makeScale())
    for await event in eventStream {
        state = try await state.advance(event)  // consuming; never escapes
    }
}

// ❌ Compile error — ~Escapable prevents this
actor MyFeature {
    var scaleState: ScaleState  // error: ~Escapable cannot be stored here
}
```

This completely eliminates the actor-storage problem from section 5 — not by working around the constraint, but by making it a compile error to even attempt it.

### When to use `~Escapable`

| Scenario | Recommendation |
|---|---|
| Long-running Task drives the machine via an event stream | ✅ Use `~Escapable` — compiler enforces the pattern |
| TCA reducer stores machine in `Feature.State` | ❌ Too restrictive; `~Copyable` alone is sufficient |
| SwiftUI ViewModel holds machine across renders | ❌ Too restrictive; `~Copyable` alone is sufficient |
| Library wants maximum compile-time safety guarantees | ✅ Use `~Escapable` with documentation |

**Recommendation:** generate `~Copyable` by default; add a `@nonescapable` annotation in the `.urkel` file or config for machines explicitly intended for the structured-task pattern.

---

## 8. Proposed Structure Walkthrough

```
┌────────────────────────────────────────────────────────────────┐
│  Generated layer (XFSMClient.swift)                            │
│                                                                │
│  XObserver<State>: ~Copyable [, ~Escapable]                    │
│    • holds XContext + transition closures                      │
│    • for @compose: also holds _yState: YState? + _makeY factory│
│    • transitions carry the sub-observer forward automatically  │
│                                                                │
│  XState: ~Copyable [, ~Escapable]                              │
│    • combined enum wrapping all typed observers                │
│    • transition methods advance X; BLE-forward methods advanc Y│
│                                                                │
│  XClient: Sendable, DependencyKey                              │
│    • makeX() → XObserver<XMachine.InitialState>                │
└────────────────────────────────────────────────────────────────┘
           ↑ factory wired via .fromRuntime()
┌────────────────────────────────────────────────────────────────┐
│  Developer layer (XClient+Live.swift etc.)                     │
│                                                                │
│  XRuntimeHandlers        named closures per transition         │
│  XRuntimeHandlers.live   connects to real hardware/network     │
│  XRuntimeHandlers.noop   silent stub for tests                 │
└────────────────────────────────────────────────────────────────┘
```

**What disappears:** `XOrchestrator`, `XSystem`, `XStateBox`, `YStateBox`. The composed machine no longer needs a separate coordinator type.

**What does not change:** `XObserver<State>` and `XState` shapes, `XClient`, `XClientRuntime`, developer `XRuntimeHandlers`. The non-composed machine model (FolderWatch) is completely unchanged.

---

## 9. Urkel Language Implications

### `@compose` — already present

```
machine Scale<ScaleContext>
@compose BLE
```

The generator uses this to:
1. Add `_bleState: BLEState?` and `_makeBLE` factory to `ScaleObserver<State>`
2. Identify the fork transition (`=> BLE.init`) that spawns BLE
3. Generate `blePowerOn()`, `bleDeviceDiscovered(device:)` etc. forwarding methods on `ScaleState`
4. Generate the `_makeBLE` parameter on `ScaleClient.makeScale()` (or inject via factory pattern)

### Cross-machine signals (`=>`) — needs design

The current grammar has `=> BLE.init` for spawning. We may need `emit` or `forward` syntax for **post-spawn** signals:

```
# Scale tells BLE to start syncing when it has data
Syncing -> syncData(payload: ScalePayload) -> PowerDown  => BLE.startSync(payload)
```

This would generate, in `ScaleObserver<ScaleMachine.Syncing>.syncData(payload:)`:

```swift
// 1. Advance Scale to PowerDown
let nextCtx = try await self._syncData(self.internalContext, payload)
// 2. Forward to embedded BLE
var nextBLE = try await self._bleState?.startSync(payload: payload)
return ScaleObserver<ScaleMachine.PowerDown>(
    internalContext: nextCtx, _bleState: nextBLE, ...
)
```

Without this grammar support, the developer writes the forwarding manually in their `RuntimeHandlers`, which is acceptable for now.

---

## 10. Migration Path

| Step | What changes | Who does it |
|---|---|---|
| 1 | Add `_bleState: YState?` + `_makeY` field generation to `XObserver<State>` in emitter | Generator |
| 2 | Fork transitions: emit `let initialY = YState(self._makeY())` + carry in return | Generator |
| 3 | Non-fork transitions: carry `_bleState: self._bleState` in every return | Generator |
| 4 | Generate `XState.yEventName(...)` BLE-forwarding consuming methods | Generator |
| 5 | Remove `XOrchestrator`, `XSystem.makeOrchestrator()`, `XStateBox` | Generator |
| 6 | Update `XClient.makeX()` signature to accept `makeY` factory | Generator |
| 7 | Update `BluetoohScale` example to use new embedded model | Example |
| 8 | Write emitter tests for sub-observer embedding and forwarding | Tests |
| 9 | Add `~Escapable` opt-in to grammar and config | Grammar + Parser |
| 10 | Update User Story US-11.2 to describe sub-observer embedding | Docs |

The non-composed machine path (FolderWatch, BluetoohBlender) is **not affected**.

---

## 11. Open Questions

**Q1: How does `makeY` reach `XClient.makeX()`?**  
Options: (a) `makeX(makeBLE: @Sendable () -> BLEObserver<BLEMachine.Off>)` parameter on the factory; (b) the two clients are always created together via an `XSystem` bundle. Option (b) is cleaner because it keeps `makeX()` unchanged for non-composed machines.

**Q2: Should BLE-forwarding methods on `ScaleState` be prefixed?**  
`blePowerOn()` vs `powerOn()` — the prefix clarifies which machine is being driven but is verbose. The convention should be documented in the generated file regardless.

**Q3: What if a state machine composes more than one other machine?**  
`@compose BLE` and `@compose Sensor` simultaneously. Each composed machine gets its own `_sensorState: SensorState?` slot. Forwarding methods are generated for all composed machines. Same pattern, scaled.

**Q4: Partial consumption of struct fields — is it stable in Swift 6.2?**  
`consume obs._bleState` where `obs` is a locally owned `~Copyable` struct should work under SE-0390. This needs explicit compiler verification once disk space allows.

**Q5: What does `~Escapable` mean for the `XClient.makeX()` factory?**  
The factory returns a `~Escapable` observer. The factory itself must be called within the scope where the observer will live. This is fine for the structured-task pattern but needs documentation so developers don't expect to call `makeX()` from one scope and use the result in another.

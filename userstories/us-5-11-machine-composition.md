# US-5.11: Machine Composition

## Objective

Emit the sub-machine embedding infrastructure for machines that use `@import` and
the fork operator `=>` (US-1.13). A parent machine carries an optional sub-machine
slot; the fork transition spawns the sub-machine; `@on Sub::State` reactive
declarations generate reaction methods on the parent's combined state enum.

## Input DSL

```
machine Scale: ScaleContext

@import BLE

@states
  init Off
  state WakingUp
  state Weighing
  final PowerDown

@transitions
  Off      -> footTap       -> WakingUp
  WakingUp -> hardwareReady -> Weighing => BLE.init
  Weighing -> weightLocked(weight: Double) -> PowerDown
  *        -> fault         -> PowerDown

@on BLE::Connected -*> / updateBLEStatus
@on BLE::Error     -> PowerDown
```

## Generated Output (delta)

The parent machine struct carries an optional sub-machine slot and factory:

```swift
public struct ScaleMachine<Phase>: ~Copyable, Sendable {
    fileprivate let _context: ScaleContext
    // … transition closures …

    // Sub-machine embedding
    fileprivate var   _bleState: BLEState?
    fileprivate let   _makeBLE: @Sendable () -> BLEState
}
```

The fork transition spawns the sub-machine:

```swift
extension ScaleMachine where Phase == ScalePhase.WakingUp {
    public consuming func hardwareReady() async throws -> ScaleMachine<ScalePhase.Weighing> {
        let next = try await _hardwareReady(_context)
        let ble  = _makeBLE()                         // ← spawn
        return ScaleMachine<ScalePhase.Weighing>(
            _context: next,
            _bleState: ble,
            _makeBLE: _makeBLE,
            /* … closures … */
        )
    }
}
```

Non-fork transitions carry the sub-machine forward:

```swift
extension ScaleMachine where Phase == ScalePhase.Weighing {
    public consuming func weightLocked(weight: Double) async throws -> ScaleMachine<ScalePhase.PowerDown> {
        let next = try await _weightLocked(_context, weight)
        return ScaleMachine<ScalePhase.PowerDown>(
            _context:  next,
            _bleState: _bleState,      // ← carry forward
            _makeBLE:  _makeBLE,
            /* … closures … */
        )
    }
}
```

`@on` reactive declarations generate methods on the **combined state enum**:

```swift
extension ScaleState {
    /// React to BLE entering `Connected` — in-place, no phase change.
    public borrowing func onBLEConnected() async {
        switch self {
        case .weighing(let m): await m._updateBLEStatus(m._context)
        default: break
        }
    }

    /// React to BLE entering `Error` — transitions Scale to `PowerDown`.
    public consuming func onBLEError() async throws -> ScaleState {
        switch consume self {
        case .weighing(let m):
            return .powerDown(try await m.fault())
        default:
            return self
        }
    }
}
```

The client factory accepts a sub-machine factory parameter:

```swift
public struct ScaleClient: Sendable {
    public var makeObserver: @Sendable (@escaping @Sendable () -> BLEState)
                             -> ScaleMachine<ScalePhase.Off>
}
```

## Acceptance Criteria

* **Given** `@import BLE` and a fork `=> BLE.init`, **when** emitted, **then**
  `ScaleMachine` has `var _bleState: BLEState?` and `let _makeBLE: @Sendable () -> BLEState`.

* **Given** the fork transition `hardwareReady`, **when** emitted, **then** it
  calls `_makeBLE()` and assigns the result to `_bleState`.

* **Given** a non-fork transition that spans a state carrying the sub-machine,
  **when** emitted, **then** `_bleState: _bleState` is forwarded to the next machine.

* **Given** `@on BLE::Connected -*> / updateBLEStatus`, **when** emitted, **then**
  `ScaleState` has `public borrowing func onBLEConnected() async`.

* **Given** `@on BLE::Error -> PowerDown`, **when** emitted, **then**
  `ScaleState` has `public consuming func onBLEError() async throws -> ScaleState`.

* **Given** the emitted `ScaleClient`, **when** examined, **then** `makeObserver`
  accepts a `@Sendable () -> BLEState` parameter.

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- Sub-machine slots and factories are discovered from `file.imports` +
  `TransitionStmt.fork` references.
- Fork parameter bindings (US-1.13 `ForkBinding`) are resolved at emit time:
  the emitter injects the bound value names as arguments to the sub-machine
  factory call.
- `@on` reactions are emitted on the combined state enum extension — they are
  not phase-constrained because the parent may be in any carrying state.
- Multiple imports generate multiple `_xxxState` / `_makeXxx` pairs.

## Testing Strategy

* Snapshot-test the Scale machine (BluetoohScale-style fixture).
* Assert `_bleState` and `_makeBLE` slots are present in the struct.
* Assert `hardwareReady()` calls `_makeBLE()`.
* Assert `weightLocked()` forwards `_bleState`.
* Assert `onBLEConnected()` is a `borrowing func` on `ScaleState`.
* Assert `onBLEError()` is a `consuming func` that returns `ScaleState`.

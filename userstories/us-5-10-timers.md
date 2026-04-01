# US-5.10: Timers

## Objective

Emit Swift concurrency-based timer infrastructure for `after(duration)` delayed
transitions (US-1.15). Each `after()` declaration generates a cancellable `Task`
handle stored inside the machine. The task is created on state entry, fires the
transition when the duration elapses, and is automatically cancelled when the
machine is consumed (moves to any other state).

## Background

`State -> after(30s) -> Dest` means: if the machine stays in `State` for 30
seconds without any other transition firing, automatically move to `Dest`.

The key safety requirement is **automatic cancellation**: because `XxxMachine` is
`~Copyable`, any `consuming` transition method takes ownership of the machine,
cancels pending timers, and constructs the next machine. There is never a leaked
`Task`.

## Input DSL

```
machine TrafficLight

@states
  init Red
  state Green
  state Yellow
  final Emergency

@transitions
  Red    -> after(30s) -> Green
  Green  -> after(25s) -> Yellow
  Yellow -> after(5s)  -> Red
  *      -> emergency  -> Emergency
```

## Generated Output (delta)

The machine carries a `Task` handle for each phase that has a timer:

```swift
public struct TrafficLightMachine<Phase>: ~Copyable, Sendable {
    // Timer task — non-nil only when a timer is active for the current phase.
    // Using `nonisolated(unsafe)` because ~Copyable + Task<Void,Never> must be
    // Sendable; the consuming semantics guarantee single-owner access.
    nonisolated(unsafe) fileprivate var _timerTask: Task<Void, Never>?
}
```

A factory method starts the timer and wires the transition callback:

```swift
extension TrafficLightMachine where Phase == TrafficLightPhase.Red {
    /// Starts the 30-second timer for the `Red → Green` delayed transition.
    /// Call immediately after entering `Red`.
    public consuming func startTimer(
        onFire: @escaping @Sendable (consuming TrafficLightMachine<TrafficLightPhase.Red>) async -> Void
    ) -> TrafficLightMachine<TrafficLightPhase.Red> {
        var m = self
        m._timerTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await onFire(consume m)
        }
        return m
    }
}
```

Every `consuming` transition that exits `Red` cancels the timer:

```swift
extension TrafficLightMachine where Phase == TrafficLightPhase.Red {
    public consuming func emergency() async throws -> TrafficLightMachine<TrafficLightPhase.Emergency> {
        _timerTask?.cancel()     // ← cancel before transition
        let next = try await _emergency()
        return TrafficLightMachine<TrafficLightPhase.Emergency>(/* … */)
    }
}
```

When the timer fires, `onFire` receives the machine and performs the scheduled
transition:

```swift
// In caller code (not generated):
var state: TrafficLightState = .red(machine.startTimer { m in
    state = .green(try await m.toGreen())
})
```

## Acceptance Criteria

* **Given** `Red -> after(30s) -> Green`, **when** emitted, **then** a
  `startTimer(onFire:)` method is generated on the `Red` phase extension.

* **Given** any `consuming` transition method that exits a phase with a timer
  (e.g., `Red -> emergency -> Emergency`), **when** emitted, **then** it calls
  `_timerTask?.cancel()` before the transition closure.

* **Given** a phase with no `after()` transitions, **when** emitted, **then**
  no `_timerTask` property or `startTimer` method is generated for that phase.

* **Given** `Task.sleep` duration, **when** the timer is started and cancelled
  before it fires, **then** the `onFire` closure is not called.

* **Given** `noop` client, **when** `startTimer` is called, **then** the timer
  task is created but the `onFire` callback transitions to the noop next phase.

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- Use `Task.sleep(for: .seconds(N))` (Swift Concurrency) — no Foundation timers.
- `_timerTask` uses `nonisolated(unsafe)` to satisfy `Sendable` while remaining
  mutable in a move-only struct.
- Timer duration units: `ms` → `.milliseconds`, `s` → `.seconds`, `min` →
  `.seconds(N * 60)`.
- Each `after()` per phase generates one `startTimer` with a distinct `onFire`
  parameter name that includes the destination state name for clarity.
- Multiple `after()` on different phases share the single `_timerTask` slot if
  only one can be active at a time (which is guaranteed by `~Copyable`).

## Testing Strategy

* Snapshot-test `stateMachine` for TrafficLight fixture.
* Assert `startTimer(onFire:)` exists on `Red`, `Green`, `Yellow` extensions.
* Assert `emergency()` cancels `_timerTask` before transitioning.
* Assert no timer infrastructure on `Emergency` (terminal, no outgoing transitions).
* Create a controlled timer test: inject a very short sleep, verify `onFire` fires.
* Verify cancellation: start timer, immediately transition via `emergency()`,
  assert `onFire` is never called.

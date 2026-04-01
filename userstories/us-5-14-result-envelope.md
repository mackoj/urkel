# US-5.14: Result Envelope Emission

## Objective

Emit a generated `XxxResult` enum that wraps all `final` states with their
typed output payloads, a `result` accessor on the combined state enum, and
an optional `async run()` free function. This makes the **caller's code**
clean, exhaustive, and testable without manually pattern-matching on the full
`XxxState` enum.

## Background

Urkel v2 supports multiple `final` states with typed payloads
(e.g. `final(weight: Double) Measurement` + `final PowerDown`). The v2
emitter already produces separate `XxxPhase.Measurement` and
`XxxPhase.PowerDown` phantom types and cases in the combined `XxxState`
enum. What is missing is the **call-site ergonomics layer**:

- A unified `XxxResult` type that is the declared output of the machine
- A `var result: XxxResult?` on `XxxState` (non-nil once a final is reached)
- An `async run(_:)` free function for machines that drive themselves

This mirrors the pattern from UML statecharts, SCXML `<donedata>`, and
XState's `output` — final states are completion events, not just "the
machine stopped."

## Input DSL (ble-scale.urkel)

```
machine BLEScale

@states
  init(scaleUUIDs: [String]) Off
  state WakingUp
  ...
  final(weight: Double, metrics: BodyMetrics) Measurement
  final PowerDown
```

## Generated Output (delta to stateMachine file)

```swift
// MARK: - BLEScale Result

/// The typed outcome of a completed `BLEScaleMachine` run.
/// Non-nil on `BLEScaleState` once any `final` phase is reached.
public enum BLEScaleResult: Sendable, Equatable {
    case measurement(weight: Double, metrics: BodyMetrics)
    case powerDown
}

// MARK: - BLEScaleState result accessor

extension BLEScaleState {
    /// The machine's typed result. Non-nil only when a final state has been reached.
    public var result: BLEScaleResult? {
        switch self {
        case .measurement(let m): return .measurement(weight: m.weight, metrics: m.metrics)
        case .powerDown:          return .powerDown
        default:                  return nil
        }
    }
}
```

When a machine has `@continuation` or `autoTransition()` support and all
final states are reachable without external events, also emit:

```swift
// MARK: - BLEScale async driver

/// Drive the machine from its initial state to any final state.
/// Returns the typed result once a final phase is reached.
/// - Note: Emitted only when the machine has eventless (always) transitions.
public func run(_ machine: consuming BLEScaleState) async throws -> BLEScaleResult {
    var current = machine
    while true {
        if let result = current.result { return result }
        guard case .idle(let m) = current else { return current.result! }
        current = try await m.autoTransition()
    }
}
```

## Acceptance Criteria

* **Given** a machine with ≥ 1 `final` state, **when** emitted, **then**
  `XxxResult` enum is generated with one case per `final` state.

* **Given** a final state with typed params (`final(x: T) S`), **when**
  emitted, **then** the `XxxResult` case has associated values matching
  the params.

* **Given** a final state with no params (`final S`), **when** emitted,
  **then** the `XxxResult` case has no associated values.

* **Given** `XxxState`, **when** emitted, **then** it has `var result:
  XxxResult?` that returns non-nil exactly for final-state cases.

* **Given** a machine with no final states, **when** emitted, **then**
  no `XxxResult` or `result` is generated.

* **Given** `XxxResult` with a single case and no params, **when** emitted,
  **then** `XxxResult` conforms to `Equatable` and `Sendable`.

* **Given** a machine with a final state that has `~Copyable` payload,
  **when** emitted, **then** `XxxResult` is also `~Copyable` (no
  `Equatable` conformance in that case).

## Notes

- `XxxResult` lives in the **state machine file** (not the client file)
- `XxxResult` should always conform to `Sendable`; `Equatable` only when
  all payload types are `Equatable`
- The `run()` free function is gated on whether the machine has `always`/
  eventless transitions — it is **not** emitted for event-driven machines
- Existing tests must not regress; this is additive

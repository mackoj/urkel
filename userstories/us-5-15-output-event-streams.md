# US-5.15: Output Event AsyncStream Emission

## Objective

Fully implement the output-event half of `-*>` (US-1.16 / US-5.8):
a `borrowing var` that returns a typed `AsyncStream` for each no-action
`-*>` declaration, a corresponding emitter closure in `XxxClientRuntime`,
and correct stream lifecycle management across all transitions that enter
or leave the phase.

US-5.8 defines the *intended design* but was only partially implemented —
in-place handlers (with action) were generated, output-event streams
(no action) were not. This story closes that gap with a precise spec.

## Background

The two `-*>` forms have opposite data-flow directions and different
generated APIs:

| Form | Direction | Already generated? |
|------|-----------|-------------------|
| `-*> event(p) / action` | Caller → machine | ✅ US-5.8 |
| `-*> event(p)` (no action) | Machine → caller | ❌ this story |

An output event is the machine *producing* data for an external consumer
while staying in the same phase. The natural Swift representation is
`AsyncStream<Payload>` — it faithfully models the sequential, ordered
nature of events, works without a platform version floor, and is
composable (can feed `@Observable`, Combine, `AsyncAlgorithms`, etc.).

**Why not `@Observable`?** `@Observable` models *current state* (latest
value wins). Output events are *transient* — every emission must be
delivered, not overwritten. The correct division of responsibility is:
generated code provides `AsyncStream`; the app's view-model layer (user-
authored or US-5.16) bridges it to `@Observable`.

**Why not a `_RunningState` actor?** The FolderWatch pattern uses an
internal actor because FSEvents fires C callbacks that cannot call async
Swift directly and requires debouncing via `AsyncAlgorithms`. Generated
machines emit from Swift async closures where
`AsyncStream.Continuation.yield` is already thread-safe — no actor
indirection is needed.

## Input DSL

```
machine Counter

@states
  init Idle
  state Active
  final Done

@entry Active / resetCount

@transitions
  Idle   -> start  -> Active
  Active -*> increment       / incrementCount   # in-place handler (US-5.8)
  Active -*> decrement       / decrementCount   # in-place handler (US-5.8)
  Active -*> value(count: Int)                  # output event ← THIS STORY
  Active -> reset  -> Active
  Active -> finish -> Done
```

## Generated Output (new artefacts only)

### 1. Output event enum

One enum per machine, one case per output event across all states.

```swift
// MARK: - Counter Output Events

/// Events emitted by CounterMachine to its observer.
/// Receive them via `machine.values` (while in `Active` phase).
public enum CounterOutput: Sendable {
    case value(count: Int)
}
```

### 2. Stream fields in machine struct

```swift
public struct CounterMachine<Phase>: ~Copyable, Sendable {
    // … transition closures …

    // Output event infrastructure
    fileprivate let _outputStream:       AsyncStream<CounterOutput>
    fileprivate let _outputContinuation: AsyncStream<CounterOutput>.Continuation
}
```

Stream is created once with `.bufferingOldest(128)` at machine construction
time (inside `makeObserver()`), so a consumer can subscribe before
`start()` without missing the first events.

### 3. `outputs` property on the emitting phase

```swift
extension CounterMachine where Phase == CounterPhase.Active {
    /// Stream of output events emitted while the machine is in `Active`.
    /// Subscribe before calling any transitions to avoid missing events.
    /// The stream finishes when the machine leaves this phase.
    public borrowing var outputs: AsyncStream<CounterOutput> { _outputStream }
}
```

Property name is always `outputs` when there is a single output event, or
each event gets its own stream property named after the event when there
are multiple:

```swift
// Multiple output events on the same phase:
// Playing -*> progress(pct: Float)
// Playing -*> bufferLevel(pct: Float)
public borrowing var progress:    AsyncStream<Float>     { _progressStream }
public borrowing var bufferLevel: AsyncStream<Float>     { _bufferLevelStream }
```

Each output event gets its own `(stream, continuation)` pair.

### 4. Continuation `.finish()` on every exit

Every `consuming func` that causes the machine to leave the phase emits
`.finish()` on all continuations declared by that phase, **before** `@exit`
actions:

```swift
extension CounterMachine where Phase == CounterPhase.Active {
    public consuming func finish() -> CounterMachine<CounterPhase.Done> {
        _outputContinuation.finish()     // ← close all output streams first
        // @exit actions would run here
        return CounterMachine<CounterPhase.Done>(…)
    }

    public consuming func reset() async -> CounterMachine<CounterPhase.Active> {
        _outputContinuation.finish()     // ← close stream before re-entering
        await _resetCount()              // @entry Active
        let (newStream, newCont) = AsyncStream<CounterOutput>
            .makeStream(bufferingPolicy: .bufferingOldest(128))
        return CounterMachine<CounterPhase.Active>(
            // … same transition closures …
            _outputStream:       newStream,
            _outputContinuation: newCont
        )
    }
}
```

**Self-transitions** (same source and destination phase, e.g. `reset →
Active`) finish the old stream and create a fresh one so a subscriber can
detect the re-entry boundary by observing stream completion.

### 5. `emitX` closure in `XxxClientRuntime`

```swift
public struct CounterClientRuntime: Sendable {
    // … existing transition closures …

    /// Call from live code to push a `value` event to the output stream.
    public typealias EmitValueAction = @Sendable (Int) -> Void
    public let emitValue: EmitValueAction
}
```

### 6. `fromRuntime` bridges emitter → continuation

```swift
extension CounterClient {
    public static func fromRuntime(_ runtime: CounterClientRuntime) -> Self {
        Self {
            let (stream, cont) = AsyncStream<CounterOutput>
                .makeStream(bufferingPolicy: .bufferingOldest(128))
            return CounterMachine<CounterPhase.Idle>(
                _start:                          runtime.startTransition,
                _reset:                          runtime.resetTransition,
                _finish:                         runtime.finishTransition,
                _incrementCountInPlaceHandler:   runtime.incrementCountAction,
                _decrementCountInPlaceHandler:   runtime.decrementCountAction,
                _resetCount:                     runtime.resetCountAction,
                _emitValue: { count in cont.yield(.value(count: count)) },
                _outputStream:                   stream,
                _outputContinuation:             cont
            )
        }
    }
}
```

### 7. `noop` closes the stream immediately on any transition

The `noop` client's `_emitValue` is `{ _ in }` (ignored). The stream is
created and finished in the `noop` machine when any exit transition runs,
so consumers get a clean, empty stream rather than hanging forever.

## Acceptance Criteria

* **Given** `Active -*> value(count: Int)` (no action), **when** emitted,
  **then** `CounterOutput` enum has a `case value(count: Int)` case.

* **Given** the above, **when** emitted, **then** `CounterMachine<Active>`
  has a `public borrowing var outputs: AsyncStream<CounterOutput>`.

* **Given** `Active -> finish -> Done`, **when** `finish()` is called,
  **then** the generated code calls `_outputContinuation.finish()` before
  returning the new machine — verified by consuming the stream and
  asserting it completes.

* **Given** a self-transition `Active -> reset -> Active`, **when** `reset()`
  is called, **then** the old stream is finished and a new stream is returned
  with the new machine.

* **Given** `CounterClientRuntime`, **when** instantiated, **then** it has
  an `emitValue: EmitValueAction` property wired to the stream continuation.

* **Given** `noop` client, **when** built, **then** subscribing to
  `.outputs` and immediately calling `finish()` produces an empty completed
  stream.

* **Given** multiple output events on the same phase, **when** emitted,
  **then** each gets its own named stream property and its own continuation,
  all finished on phase exit.

* **Given** all emitted files, **when** parsed by SwiftParser, **then** no
  syntax errors.

## Testing Strategy

* Snapshot-test `CounterMachine.swift` with the counter fixture.
* Unit-test: `fromRuntime` — call `emitValue(42)`, subscribe to `outputs`,
  assert `.value(count: 42)` is received.
* Unit-test: `finish()` closes the stream — `for await _ in outputs` must
  complete after `finish()`.
* Unit-test: `reset()` closes old stream, new machine has a fresh stream.
* Unit-test: `noop` — stream completes after `finish()`.
* Property-based test: emit N values, finish, collect all — count matches N.

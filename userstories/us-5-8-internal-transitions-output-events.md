# US-5.8: Internal Transitions & Output Events

## Objective

Emit two distinct Swift patterns for `-*>` declarations (US-1.8, US-1.16):

1. **In-place handler** (`-*>` + action): a `borrowing func` that runs a side
   effect but does **not** consume the machine and does **not** change its phase.
2. **Output event** (`-*>` without action): a `borrowing var` that returns an
   `AsyncStream<T>`, letting the caller observe values the machine emits while
   staying in the current phase.

## Background

`-*>` is the "stay in state" arrow. Its two forms have opposite data-flow
directions:

| Arrow form | Direction | Generated API |
|------------|-----------|---------------|
| `-*> event(p) / action` | Caller → machine | `borrowing func event(p:)` |
| `-*> event(p)` (no action) | Machine → caller | `borrowing var event: AsyncStream<P>` |

`borrowing func` (not `consuming`) is critical: it proves at the call site that
the machine is NOT consumed — the phase is unchanged, the caller retains
ownership.

## Input DSL

```
machine VideoPlayer: PlayerContext

@states
  init Idle
  state Playing
  final Stopped

@entry Playing / startAnalytics
@exit  Playing / stopAnalytics

@transitions
  Idle    -> play(url: URL) -> Playing
  Playing -> stop           -> Stopped

  # In-place handler — caller sends seek; machine runs action; stays Playing
  Playing -*> seek(position: Double)        / emitSeekUI

  # Output event — machine emits progress to caller; caller reads stream
  Playing -*> progress(pct: Float)
```

## Generated Output (delta)

### In-place handler

```swift
extension VideoPlayerMachine where Phase == VideoPlayerPhase.Playing {
    /// Handles `seek` in-place. The machine remains in the `Playing` phase.
    public borrowing func seek(position: Double) async {
        await _emitSeekUI(_context, position)
    }
}
```

Note: return type is `Void` — the machine is not consumed and the phase is
unchanged. The function is `async` (action may be async) but **not** `throws`
(actions cannot affect control flow per US-1.7).

### Output event

The stream is stored in the machine struct as a `(stream, continuation)` pair.
The stream is created once when the machine enters the `Playing` phase and is
finished when the machine leaves (via `consuming` transition methods that call
`_progressContinuation.finish()`).

```swift
public struct VideoPlayerMachine<Phase>: ~Copyable, Sendable {
    // … context, transition closures …

    // Output event infrastructure — only meaningful in Playing phase
    fileprivate let _progressStream: AsyncStream<Float>
    fileprivate let _progressContinuation: AsyncStream<Float>.Continuation
}

extension VideoPlayerMachine where Phase == VideoPlayerPhase.Playing {
    /// Stream of progress values emitted by the machine while in `Playing`.
    /// Subscribe before starting playback. Finishes when the machine transitions out.
    public borrowing var progress: AsyncStream<Float> { _progressStream }
}
```

The continuation is wired into the context's implementation — the caller injects
a closure that receives the continuation and drives it:

```swift
// In XxxClientRuntime:
public typealias ProgressProducer = @Sendable (
    PlayerContext,
    AsyncStream<Float>.Continuation
) async -> Void
```

When the machine transitions OUT of `Playing` (e.g., calls `stop()`), the emitter
generates a `_progressContinuation.finish()` call to close the stream:

```swift
extension VideoPlayerMachine where Phase == VideoPlayerPhase.Playing {
    public consuming func stop() async throws -> VideoPlayerMachine<VideoPlayerPhase.Stopped> {
        _progressContinuation.finish()          // ← close output streams
        await _stopAnalytics(_context)          // @exit
        let next = try await _stop(_context)
        return VideoPlayerMachine<VideoPlayerPhase.Stopped>(…)
    }
}
```

## Acceptance Criteria

* **Given** `Playing -*> seek(position: Double) / emitSeekUI`, **when** emitted,
  **then** a `public borrowing func seek(position: Double) async` is generated
  on the `Playing` extension — **not** a `consuming` method.

* **Given** `Playing -*> progress(pct: Float)` (no action), **when** emitted,
  **then** a `public borrowing var progress: AsyncStream<Float>` is generated on
  the `Playing` extension.

* **Given** a machine with output events, **when** any transition **leaves** the
  phase that declared the output event, **then** the generated transition method
  calls `.finish()` on each output event continuation.

* **Given** a machine with multiple output events on the same phase, **when**
  emitted, **then** a separate `AsyncStream` / `Continuation` pair is generated
  for each output event.

* **Given** `noop` client, **when** its machine transitions through `Playing`,
  **then** the `progress` stream immediately finishes (empty).

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- Detect `-*>` with action: `transition.arrow == .internal && transition.action != nil`.
- Detect output event: `transition.arrow == .internal && transition.action == nil`.
- For output events: add `(AsyncStream<T>, AsyncStream<T>.Continuation)` fields
  to machine struct.
- In every `consuming func` that exits the phase declaring the output event:
  emit `.finish()` calls before any `@exit` actions.
- In `XxxClientRuntime`, add a `XxxProducer` typealias and closure for each
  output event, enabling the implementer to drive the stream.

## Testing Strategy

* Snapshot-test `stateMachine` for the VideoPlayer fixture.
* Assert `seek(position:)` is a `borrowing func` (not `consuming`).
* Assert `progress` is a `borrowing var` of type `AsyncStream<Float>`.
* Assert that `stop()` calls `_progressContinuation.finish()`.
* Construct a noop VideoPlayer, subscribe to `.progress`, call `stop()`,
  and assert the stream ends (i.e., `for await _ in stream` completes).

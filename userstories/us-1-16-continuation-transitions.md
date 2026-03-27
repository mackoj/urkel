# US-1.16: Stream Production Pattern

## Objective

Document the idiomatic way to model a state that continuously produces a stream of values while active — using `@entry`/`@exit` for producer lifecycle and explicit transitions for errors and natural completion. This is a **convention**, not a new DSL keyword.

## Background

Some states exist because the machine is actively producing a sequence of values: a folder watcher emitting file-system events, a BLE connection streaming sensor readings, a price feed emitting quotes. The machine stays in that state for as long as the stream is active.

This looks like it needs special syntax. It does not. The existing DSL already has everything needed:

- `@entry State / startProducer` — starts the producer when the state is entered (US-1.7)
- `@exit  State / stopProducer` — cancels the producer when the state is exited (US-1.7)
- Explicit transitions for errors from the producer (US-1.1, US-1.2)
- An optional transition for natural stream completion (producer finished normally)

The producer itself — what kind of stream it is, how it delivers values to the caller — is a **generated API detail** specific to the target language. The DSL describes the lifecycle and the error paths; the code generator handles how values flow to the consumer.

## The Pattern

### Full form

```
machine FolderWatch

@states
  init(directory: URL, debounceMs: Int) Idle
  state Running
  state Error
  final Stopped

@entry Running / startWatching    # starts the directory producer
@exit  Running / stopWatching     # cancels it when the state is exited for any reason

@transitions
  Idle    -> start              -> Running

  # Errors from the producer are explicit transitions
  Running -> watchError(error: Error) -> Error

  # Natural completion (producer signalled it is done)
  Running -> watchCompleted -> Stopped

  # Caller-driven stop
  Running -> stop -> Stopped

  Error   -> retry -> Running
  Error   -> stop  -> Stopped
```

### Why `@exit` covers all exits

`@exit Running / stopWatching` fires on **every** transition out of `Running`:

- `Running -> watchError -> Error` → `stopWatching` fires
- `Running -> watchCompleted -> Stopped` → `stopWatching` fires
- `Running -> stop -> Stopped` → `stopWatching` fires

The producer is always cleaned up. The implementation of `stopWatching` should be safe to call even if the producer has already stopped.

### Recoverable error (stay in Running)

If the producer encounters a transient error but should keep running:

```
# Error is logged as a side effect; machine stays in Running
Running -*> watchError(error: Error) / logWatchError
```

Using `-*>` means: handle the error event in-place, no exit/re-entry, `stopWatching`/`startWatching` do **not** fire. See [US-1.8](us-1-8-internal-and-wildcard-transitions.md).

### Without natural completion (indefinite stream)

```
@entry Running / startWatching
@exit  Running / stopWatching

@transitions
  Idle    -> start -> Running
  Running -> stop  -> Stopped

  Running -*> watchError(error: Error) / logError   # recoverable, stays Running
```

### Multiple producers in the same state

```
@entry Connected / startMeasurements, startHeartbeat
@exit  Connected / stopMeasurements,  stopHeartbeat

@transitions
  Connected -> measurementError(error: Error) -> Error
  Connected -> disconnect                      -> Idle
```

## Naming convention

Name entry/exit actions and error events from the **producer's perspective**:

```
# Good — describes the producer
@entry Running / startWatching
@exit  Running / stopWatching
Running -> watchError(error: Error) -> Error

# Avoid — too generic
@entry Running / start
@exit  Running / stop
Running -> error(error: Error) -> Error
```

## Why not `@continuation`?

A `@continuation` keyword was considered for Urkel. It was removed because:

1. **It is not a FSM primitive** — no equivalent exists in XState, SCXML, or Harel statecharts.
2. **It is language-specific** — `AsyncThrowingStream<T, Error>` is a Swift concept. The DSL should be target-language agnostic.
3. **The existing constructs already express the intent** — `@entry`/`@exit` manage the producer lifecycle completely; error paths are explicit transitions.
4. **The stream's delivery mechanism is a code generation concern** — how values flow from the producer to the consumer (a channel, an async sequence, a callback) depends on the target language and is appropriately handled by the emitter, not declared in the DSL.

## Notes

- There is no DSL-level distinction between a "streaming state" and any other state. The pattern is entirely a matter of what `@entry`/`@exit` and transitions you attach.
- The entry action name (`startWatching`) and exit action name (`stopWatching`) appear on the machine's injectable `Client` struct, making the producer lifecycle an explicit part of the generated API contract.
- Combine this pattern with `after(duration)` (US-1.15) if the producer should time out: `Running -> after(30s) -> TimedOut`.
- If the producer can restart after an error, combine with the async loading pattern (US-1.14): `Error -> retry -> Running` re-enters `Running`, which fires `@entry Running / startWatching` again automatically.

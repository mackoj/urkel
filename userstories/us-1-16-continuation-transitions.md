# US-1.16: Stream Production Pattern

## Objective

Model a state that continuously produces a stream of values while active. Output events — `-*>` declarations with **no action** — are the DSL mechanism: they declare what the machine emits from a state. The code generator turns them into a typed stream accessible to the caller.

## Background

Some states exist because the machine is actively producing a sequence of values: a folder watcher emitting file-system events, a BLE connection streaming sensor readings, a price feed emitting quotes. The machine stays in that state for as long as the stream is active.

The Urkel DSL handles this with two cooperating constructs:

1. **`@entry`/`@exit`** — manage the producer lifecycle (start and stop the background task).
2. **Output events** (`-*>` with no action) — declare what the machine emits while in that state. The generator creates a typed stream for each one.

The shape of the stream (async sequence, callback, channel) is a code generation concern specific to the target language. The DSL only declares the event name and its payload.

## DSL Syntax

### Core pattern

```
machine FolderWatch

@states
  init(directory: URL, debounceMs: Int) Idle
  state Running
  state Error
  final Stopped

@entry Running / startWatching    # starts the directory watcher
@exit  Running / stopWatching     # cancels it when the state is exited for any reason

@transitions
  Idle    -> start -> Running

  # Output event: machine emits this to the caller; generator creates a stream
  Running -*> directoryChanged(event: DirectoryEvent)

  # Hard error: producer failed unrecoverably → state change
  Running -> watchFailed(error: Error) -> Error

  # Soft error: transient; logged in-place, stays Running
  Running -*> watchWarning(error: Error) / logWarning

  # Natural completion or caller stop
  Running -> watchCompleted -> Stopped
  Running -> stop           -> Stopped

  Error   -> retry -> Running
  Error   -> stop  -> Stopped
```

### The two forms of `-*>`

| Form | Has action? | Meaning |
|------|-------------|---------|
| `State -*> event(params) / action` | Yes | In-place handler — caller sends event, machine runs action |
| `State -*> event(params)` | No | **Output event** — machine emits this to caller; generator creates stream |

The distinction is direction:
- **In-place handler**: caller → machine. The caller fires the event; the machine handles it without leaving the state.
- **Output event**: machine → caller. The producer (started by `@entry`) fires the event; the caller receives it as a stream element.

### Multiple output events from one state

```
@entry Connected / startSensor
@exit  Connected / stopSensor

Connected -*> measurement(bpm: Int)          # stream 1
Connected -*> statusUpdate(status: String)   # stream 2
Connected -> sensorError(error: Error) -> Error
Connected -> disconnect -> Idle
```

Each output event becomes its own stream property on the generated machine type for that state.

### Output event without `@entry`/`@exit`

`@entry`/`@exit` are not required — the output event declaration is independent. A state can declare output events and rely on the client implementation to drive them:

```
Running -*> tick(elapsed: TimeInterval)   # output; caller observes elapsed ticks
Running -> stop -> Stopped
```

## Why `@exit` covers all exits

`@exit Running / stopWatching` fires on **every** transition out of `Running`:

- `Running -> watchFailed -> Error` → `stopWatching` fires
- `Running -> watchCompleted -> Stopped` → `stopWatching` fires
- `Running -> stop -> Stopped` → `stopWatching` fires

The producer is always cleaned up. The `stopWatching` implementation should be safe to call even if the producer has already finished.

## Acceptance Criteria

* **Given** `Running -*> directoryChanged(event: DirectoryEvent)` with no action, **when** processed, **then** it is recognized as an output event declaration — the generator creates a stream of `DirectoryEvent` accessible from the `Running`-state machine.

* **Given** a state with both an output event and `@entry`/`@exit` actions, **when** the state is entered, **then** the `@entry` action fires; as the producer emits, output events populate the stream; when the state is exited, the `@exit` action fires and the stream is closed.

* **Given** `State -*> event(params)` with no action and no parameters, **when** validated, **then** a warning is emitted: `"Output event 'event' has no parameters — it conveys no data to the caller; consider adding parameters or an action"`.

* **Given** two output events with the same name on the same source state, **when** validated, **then** an error is emitted: `"Duplicate output event 'X' on state 'S'"`.

* **Given** an output event on a `final` state, **when** validated, **then** an error is emitted: `"Final states cannot declare output events"`.

* **Given** a machine with output events, **when** code is generated, **then** each output event becomes a typed stream property on the machine constrained to that state — inaccessible when the machine is in any other state.

## Why not `@continuation`?

`@continuation` was removed because:

1. **Language-specific types** — `AsyncThrowingStream<T, Error>` is Swift. The DSL must be target-language agnostic.
2. **Not a FSM primitive** — no equivalent exists in XState, SCXML, or Harel statecharts.
3. **Output events replace it cleanly** — `-*>` without action expresses the same intent: a value produced from a stable state, language-agnostically.

## Notes

- Output events combine naturally with `after(duration)` (US-1.15): if the state times out, the stream is closed and the machine transitions.
- Output events combine with compound reactive conditions (US-1.17): a parent machine can react via `@on` when a child machine's output stream fires (the child emits an output event → child transitions → parent reacts to child's new state).
- The generator decides what "stream" means per target language: `AsyncStream` in Swift, `Flow` in Kotlin, an `Observable` in Rx-based targets, etc.
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

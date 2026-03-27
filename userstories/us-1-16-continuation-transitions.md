# US-1.16: Continuation Transitions

## Objective

Allow a state to expose a named, non-consuming accessor that produces a stream of values — a transition that does not change state but returns a live sequence the caller can observe.

## Background

Some states do not just transition in response to external events — they continuously produce values while active. A folder-watcher stays in `Running` and emits a stream of `DirectoryEvent` values. A BLE connection stays in `Connected` and streams sensor readings. A live ticker stays in `Active` and emits periodic prices.

These are not transitions in the traditional sense: the machine stays in the same state while the sequence is active. The caller gets back a typed stream and can iterate over it for as long as the state holds.

Urkel models this with two cooperating constructs:

1. **An incomplete transition** in `@transitions` — a source state and an event name with **no destination** (`Running -> events`). The missing destination signals "this does not change state; it produces a value."

2. **A `@continuation` block** at the top level — declares the return type for each named incomplete transition.

The name `continuation` reflects that the machine _continues_ in its current state while the caller reads the produced sequence.

## DSL Syntax

```
machine FolderWatch

@states
  init(directory: URL, debounceMs: Int) Idle
  state Running
  final Stopped

@transitions
  Idle    -> start -> Running
  Running -> stop  -> Stopped

  # Incomplete transition: no destination — produces a value stream
  Running -> events
  Running -> error(error: Error) -> Running   # recoverable error, stays Running

@continuation
  events -> AsyncThrowingStream<DirectoryEvent, Error>
```

### Multiple continuations

```
@transitions
  Connected -> measurements
  Connected -> statusUpdates

@continuation
  measurements   -> AsyncStream<Measurement>
  statusUpdates  -> AsyncStream<StatusUpdate>
```

### Continuation with parameters

```
@transitions
  Active -> priceUpdates(symbol: String)

@continuation
  priceUpdates -> AsyncStream<PriceQuote>
```

## Acceptance Criteria

* **Given** `Running -> events` (no destination), **when** processed, **then** it is recognized as a continuation transition — a non-consuming accessor that does not change the machine's state type.

* **Given** `@continuation` with `events -> AsyncThrowingStream<DirectoryEvent, Error>`, **when** processed, **then** `events` is matched to the incomplete transition and its return type is captured.

* **Given** an incomplete transition `State -> eventName` with no corresponding entry in `@continuation`, **when** validated, **then** an error is emitted: `"Incomplete transition 'eventName' from 'State' has no @continuation return type"`.

* **Given** a `@continuation` entry `eventName -> ReturnType` with no matching incomplete transition, **when** validated, **then** an error is emitted: `"@continuation declares 'eventName' but no incomplete transition for 'eventName' exists"`.

* **Given** an incomplete transition where the event name has parameters (`Running -> measurements(filter: String)`), **when** processed, **then** the parameters are valid — the caller passes them when requesting the stream.

* **Given** an incomplete transition on a `final` state, **when** validated, **then** an error is emitted: `"Final states cannot declare continuation transitions"`.

* **Given** an incomplete transition on a state that is not a `state` kind (e.g., on an `init` state), **when** validated, **then** a **warning** is emitted: `"Continuation transition on 'init' state 'X' — consider whether this is intentional"`.

* **Given** a machine with continuation transitions and no `@continuation` block, **when** validated, **then** an error is emitted: `"Machine has incomplete transitions but no @continuation block"`.

## Grammar

```ebnf
TransitionStmt    ::= Identifier "->" EventDecl ("->" Identifier ForkClause? ActionClause?)? Newline
ContinuationBlock ::= "@continuation" Newline ContinuationEntry+
ContinuationEntry ::= Identifier "->" ReturnType Newline
ReturnType        ::= (any non-newline characters forming a valid host-language type)
```

An incomplete transition is one where the `"->" Identifier` destination segment is omitted. This is a distinct syntactic form — the single arrow followed immediately by a newline is unambiguous.

## Notes

- Continuation transitions use the host language's native async sequence types. The DSL captures the return type verbatim — it does not parse or validate it.
- The machine remains in its current state while the caller iterates the continuation. The continuation ends when the state is exited (the stream is cancelled/completed by the runtime).
- This construct combines with US-1.3 (core transitions) to produce a machine that can both transition to new states and stream values from a stable state — these are not mutually exclusive.
- The `@continuation` block appears after `@transitions` in the file.

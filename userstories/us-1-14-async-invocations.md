# US-1.14: Async Invocations

## Objective

Allow a state to declare an asynchronous operation that starts automatically on entry and produces either a `onDone` or `onError` transition outcome — making the intent of a loading or waiting state explicit and visible in the DSL.

## Background

The most common pattern in real-world state machines is a **loading state**: the machine enters a state because it is waiting for an async operation (a network call, a file read, a database query). Without `@invoke`, this intent is invisible to the DSL — the developer writes the async call inside an injected closure, and the DSL just sees a state with no self-documenting annotations.

`@invoke` makes async intent a first-class part of the machine declaration. When the machine enters a state with `@invoke`, the named async operation starts automatically. When it finishes:

- **`onDone`** fires with the result value and transitions to the success target state.
- **`onError`** fires with the thrown error and transitions to the failure target state.

If the machine exits the state before the operation completes (e.g., a cancel event fires), the in-flight operation is cancelled automatically.

Like guards and actions, the invoked service is **named in the DSL** and **implemented in the host language**, injected at construction time.

## DSL Syntax

```
machine UserProfile<ProfileContext>

@states
  init Idle
  state Loading
    @invoke fetchUser(id: UserID) -> User
      onDone(user: User)    -> Success
      onError(error: Error) -> Failure
  state Success
  state Failure
  final Closed

@transitions
  Idle    -> load(id: UserID) -> Loading
  Success -> reload(id: UserID) -> Loading
  Failure -> retry(id: UserID)  -> Loading
  Success -> close -> Closed
  Failure -> close -> Closed
```

### `@invoke` with no result type

```
state Connecting
  @invoke openSocket(url: URL)
    onDone              -> Connected
    onError(error: Error) -> Error
```

### `@invoke` with no `onError` (non-throwing service)

```
state Preloading
  @invoke warmCache(config: CacheConfig) -> CacheResult
    onDone(result: CacheResult) -> Ready
```

### `@invoke` inside a compound state (US-1.10)

```
state Playing
  state Streaming
    @invoke fetchNextChunk(position: Double) -> Chunk
      onDone(chunk: Chunk)    -> Streaming    # self-transition with result
      onError(error: Error)   -> BufferError
  state Paused
```

## Acceptance Criteria

* **Given** a state with `@invoke serviceName(params) -> ResultType`, **when** the machine enters that state, **then** the named async service starts automatically.

* **Given** an `onDone(result: ResultType) -> TargetState` clause, **when** the invoked operation completes successfully, **then** the machine automatically transitions to `TargetState` carrying `result` as an event parameter.

* **Given** an `onError(error: Error) -> TargetState` clause, **when** the invoked operation throws, **then** the machine automatically transitions to `TargetState` carrying `error` as an event parameter.

* **Given** a state with `@invoke` and an explicit event transition (`cancel -> Idle`) on the same state, **when** the `cancel` event fires before the invocation completes, **then** the in-flight operation is cancelled and `cancel` transition fires normally.

* **Given** `@invoke` with no `onError` clause, **when** processed, **then** the service is treated as non-throwing — any error thrown is an unhandled failure; a warning is emitted if the service signature indicates it can throw.

* **Given** `@invoke` declared on a `final` state, **when** validated, **then** an error is emitted: `"@invoke cannot be declared on a final state"`.

* **Given** a state with more than one `@invoke` declaration, **when** validated, **then** an error is emitted: `"A state may declare at most one @invoke"`.

* **Given** an `onDone` or `onError` target state that does not appear in `@states`, **when** validated, **then** an error is emitted: `"Unknown state 'X' in @invoke onDone/onError"`.

* **Given** the invoked service name is the same as an existing event name in `@transitions`, **when** validated, **then** an error is emitted: `"Invocation name 'X' conflicts with event name 'X'"`.

## Grammar

```ebnf
InvokeDecl        ::= "@invoke" Identifier "(" ParameterList? ")" ("->" TypeIdentifier)? Newline
                      Indent InvokeDoneClause InvokeErrorClause? Dedent
InvokeDoneClause  ::= "onDone" ("(" ParameterList ")")? "->" Identifier Newline
InvokeErrorClause ::= "onError" ("(" ParameterList ")")? "->" Identifier Newline
```

`@invoke` is declared as a child block inside a `state` declaration, indented one level.

## Notes

- `@invoke` service names, like guard and action names, are part of the machine's injectable contract — each unique name becomes a typed async closure property on the generated client.
- The `onDone` result parameter name becomes an argument label on the auto-generated transition. Choose it carefully.
- For time-based automatic transitions (fire after a fixed delay), see US-1.15.

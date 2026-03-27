# US-1.14: Async Loading Pattern

## Objective

Document the **async loading pattern** — the idiomatic way to express a state that kicks off an async operation on entry, handles its success and failure outcomes as regular transitions, and cancels the in-flight work if the state is exited early. This is a **convention**, not a new DSL keyword.

## Background

The most common pattern in real-world state machines is a state that exists solely because the machine is waiting for an async operation to complete: a network call, a database query, a file read. Naively, this looks like it needs special syntax. It does not.

The existing DSL already has everything needed:

- `@entry State / startOp` — kicks off the work when the state is entered (US-1.7)
- Explicit completion events as regular transitions (US-1.1, US-1.2)
- `@exit State / cancelOp` — cancels the in-flight work if the state is exited before completion (US-1.7)

`@invoke` (present in tools like XState) is a convenience wrapper around exactly this pattern. Urkel does not need it as a first-class keyword because the base constructs compose cleanly and the result is more explicit, not less.

## The Pattern

### Full form

```
machine UserProfile: ProfileContext

@states
  init Idle
  state Loading
  state Success
  state Failure
  final Closed

# Async loading pattern for Loading:
@entry Loading / fetchUser       # start the async op when Loading is entered
@exit  Loading / cancelFetchUser # cancel it if we leave before it finishes

@transitions
  Idle    -> load(id: UserID)              -> Loading
  Success -> reload(id: UserID)            -> Loading

  # Completion events — fired by the fetchUser implementation when done
  Loading -> fetchUserSucceeded(user: User) -> Success
  Loading -> fetchUserFailed(error: Error)  -> Failure

  Success -> close -> Closed
  Failure -> close -> Closed
```

### Without cancellation (non-cancellable op)

```
@entry Loading / fetchUser

@transitions
  Loading -> fetchUserSucceeded(user: User) -> Success
  Loading -> fetchUserFailed(error: Error)  -> Failure
```

### Non-throwing op (no failure path)

```
@entry Preloading / warmCache

@transitions
  Preloading -> cacheWarmed(result: CacheResult) -> Ready
```

### Cancellable op with explicit cancel event

```
@entry Uploading / startUpload
@exit  Uploading / cancelUpload

@transitions
  Uploading -> uploadSucceeded(url: URL)    -> Done
  Uploading -> uploadFailed(error: Error)   -> Error
  Uploading -> cancel                       -> Idle  # caller-triggered cancel
```

Note: `@exit` fires for **all** exits from `Uploading` — including the `cancel` transition — so `cancelUpload` is always called when leaving the state. The implementation should be safe to call redundantly (e.g., cancel a task that may already have completed).

### Inside a compound state (US-1.10)

```
@states
  state Playing
    state Buffering
    state Streaming

@entry Playing.Buffering / fetchChunk
@exit  Playing.Buffering / cancelChunk

@transitions
  Playing.Buffering -> chunkReady(chunk: Chunk)   -> Playing.Streaming
  Playing.Buffering -> chunkFailed(error: Error)  -> Error
```

## Why not `@invoke`?

`@invoke` would save writing two lifecycle declarations and two transitions, at the cost of introducing a nested block construct that breaks the flat-table principle of the DSL:

```
# @invoke (not in Urkel) — hides the structure:
state Loading
  @invoke fetchUser(id: UserID) -> User
    onDone(user: User)    -> Success
    onError(error: Error) -> Failure

# Urkel pattern — structure is explicit and consistent:
@entry Loading / fetchUser
@exit  Loading / cancelFetchUser

@transitions
  Loading -> fetchUserSucceeded(user: User) -> Success
  Loading -> fetchUserFailed(error: Error)  -> Failure
```

The explicit form:
- Keeps all transitions in `@transitions` where they belong
- Makes cancellation an explicit, named contract (not a hidden side effect)
- Uses the same constructs the reader already knows — no new syntax to learn
- Allows fine-grained naming: `fetchUserSucceeded` carries more intent than `onDone`

## Naming convention

Completion events should be named from the **operation's perspective**, not from the state's perspective. Prefer:

```
# Good — describes what happened
Loading -> fetchUserSucceeded(user: User) -> Success
Loading -> fetchUserFailed(error: Error)  -> Failure

# Avoid — describes the state machine's reaction, not the event
Loading -> done(user: User)  -> Success
Loading -> error(error: Error) -> Failure
```

## Notes

- There is no DSL-level distinction between a "loading state" and any other state. The pattern is entirely a matter of what `@entry`/`@exit` and transitions you attach to it.
- The entry action name (`fetchUser`) and the cancellation action name (`cancelFetchUser`) both appear on the machine's injectable `Client` struct, making the async lifecycle explicit in the generated API.
- If a state needs both an async operation AND a timed fallback, combine this pattern with a delayed transition (US-1.15): `Loading -> after(10s) -> TimedOut`.

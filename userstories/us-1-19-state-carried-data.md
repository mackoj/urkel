# US-1.19: State-Carried Data

## Objective

Allow any state — not just `init` and `final` — to declare typed parameters
that are captured on entry and exposed as read-only properties while the machine
is in that state. This makes non-terminal states first-class carriers of data,
closing the symmetry gap with `init(params)` and `final(params)`.

## Background

`init(params) StateName` and `final StateName(params)` already carry typed data.
But regular `state` declarations cannot. This creates an asymmetry: once a machine
has loaded data, the only clean way to expose it is through a `final` state (which
ends the machine) or through a separate output event stream (US-1.16), neither of
which is appropriate when the machine must remain active and the data must be
queryable at any time while in that state.

Consider a fetch machine that transitions into a `Loaded` state and stays there
until the caller refetches or dismisses. The loaded `data` should be a typed
property of the `Loaded` state — just as `directory` is a typed property of the
`init` state in a FolderWatch machine.

Allowing params on all `state` kinds also unlocks **cross-machine data flow via
`@on`** (see Notes): a parent machine reacting to a child's state change can
access the child's state-carried data through its dependency context, without any
new DSL mechanism.

## DSL Syntax

```
machine DataFetch

@states
  init Idle
  state Loading
  state Loaded(data: Data, source: URL)    # non-final state carrying typed data
  state Error(reason: String, code: Int)
  final(data: Data) Done

@entry Loading / showSpinner
@exit  Loading / hideSpinner

@transitions
  Idle    -> fetch(url: URL)                          -> Loading

  # Both params in the event match the Loaded state's declared params by name.
  Loading -> fetchSuccess(data: Data, source: URL)    -> Loaded
  Loading -> fetchFailure(reason: String, code: Int)  -> Error
  Loading -> after(30s)                               -> Error   # GAP: no params supplied → validator error

  Loaded  -> accept                                   -> Done    # final(data: Data) captures from Loaded
  Loaded  -> refetch(url: URL)                        -> Loading
  Error   -> retry(url: URL)                          -> Loading
  Error   -> dismiss                                  -> Idle
```

### Partial param capture (event carries more than the state needs)

The state declaration is the **capture contract**: it declares which params it
retains. An inbound transition may carry additional params that the state does not
capture — they are used for the transition logic only.

```
state Loaded(data: Data)

# Extra param `etag` is used in the transition but not retained by Loaded.
Loading -> fetchSuccess(data: Data, etag: String) -> Loaded
```

### Cross-state param propagation

Downstream transitions inherit nothing from the source state's params automatically.
To pass data from a state to a final state, the exiting transition must re-declare it.

```
state Loaded(data: Data)
final(data: Data) Done

# `data` must appear in the `accept` transition for Done to receive it.
Loaded -> accept(data: Data) -> Done

# Without data in the transition:
# Loaded -> accept -> Done   ← validator error: Done requires `data`
```

### Common patterns

#### Load-then-display (data available while in non-final state)

```
machine ArticleFeed

@states
  init Idle
  state Refreshing
  state Displaying(articles: [Article], cursor: String?)
  state Error(message: String)
  final Dismissed

@transitions
  Idle        -> load                                                -> Refreshing
  Refreshing  -> loaded(articles: [Article], cursor: String?)       -> Displaying
  Refreshing  -> failed(message: String)                            -> Error
  Displaying  -> loadMore                                           -> Refreshing
  Displaying  -> dismiss                                            -> Dismissed
  Error       -> retry                                              -> Refreshing
  Error       -> dismiss                                            -> Dismissed
```

#### History state with last-known value

```
machine HeartRate

@states
  init Off
  state Activating
  state Idle(bpm: Int)         # carries last measured value
  state Measuring
  final Terminated

@transitions
  Off        -> activate                             -> Activating
  Activating -> sensorReady(bpm: Int)                -> Idle
  Idle       -> startMeasurement                     -> Measuring
  Measuring  -> measurementComplete(bpm: Int)        -> Idle
  *          -> deactivate                           -> Terminated
```

The parent machine can react to `HeartRate::Idle` via `@on` and access `bpm`
through the child's dependency context (see Notes).

## Acceptance Criteria

* **Given** `state Loaded(data: Data, source: URL)`, **when** a transition
  `Loading -> fetchSuccess(data: Data, source: URL) -> Loaded` fires, **then**
  the machine in the `Loaded` state exposes `data` and `source` as read-only
  typed properties accessible in generated code.

* **Given** an inbound transition that does **not** supply all required state params
  (e.g. `Loading -> fetchSuccess(data: Data) -> Loaded` when `Loaded` also requires
  `source: URL`), **when** validated, **then** an error is emitted:
  `"Transition to 'Loaded' must supply param 'source: URL'"`.

* **Given** multiple inbound transitions to the same state, **when** validated,
  **then** every inbound transition must supply all declared state params by name
  and type — a mismatch on any one is a validation error.

* **Given** an inbound transition carrying **extra** params not declared on the
  state (`fetchSuccess(data: Data, etag: String) -> Loaded` where `Loaded` only
  declares `data: Data`), **when** validated, **then** no error or warning —
  extra params are used only during the transition and are not retained.

* **Given** `state Name(params)` with no inbound transitions in the whole machine,
  **when** validated, **then** a warning is emitted: `"State 'Name' is unreachable"`.

* **Given** a downstream transition from a state with params (e.g.
  `Loaded -> accept -> Done` where `Done` requires `data: Data`), **when**
  validated, **then** an error is emitted if the `accept` event does not carry
  the required `data` param for `Done`. The state's own params are **not**
  implicitly forwarded.

* **Given** `state Name(params)` in the `@states` block, **when** code is
  generated, **then** the generated machine type for that state exposes each
  declared param as a stored, read-only, typed property.

## Grammar

Extension to `SimpleStateDecl` (already supports `init` and `final` with params):

```ebnf
SimpleStateDecl ::= { Whitespace } StateKind
                    [ "(" ParameterList ")" ]
                    { Whitespace } Identifier
                    [ { Whitespace } HistoryModifier ]
                    { Whitespace } Newline

StateKind ::= "init" | "state" | "final"
```

The `[ "(" ParameterList ")" ]` clause is now valid for **all three** state kinds.
Previously it was only generated for `init` and `final`.

## Notes

- **Cross-machine data flow via `@on`** (resolves GAP-4): When a parent machine
  uses `@on Child::SomeState -*> / action`, the implementing `action` function
  receives the child machine in its `SomeState` context, which includes the state's
  typed params as properties. No new DSL syntax is needed — the data flows through
  the generated API naturally.

  ```
  # Child HeartRate has: state Idle(bpm: Int)
  # Parent SmartWatch:
  @on HeartRate::Idle -*> / updateBPMDisplay
  # The `updateBPMDisplay` action receives HeartRate in Idle state,
  # where .bpm is accessible as a typed property.
  ```

- **Symmetry with `init` and `final`**: All three state kinds now have a uniform
  param syntax. The semantic difference is lifecycle:
  - `init(params)` — params are construction-time inputs; set once at machine creation
  - `state(params)` — params are transition-time inputs; set each time the state is entered
  - `final(params)` — params are terminal outputs; set on the last transition

- **`@history` and params**: A state can have both `@history` and params. When history
  restores a compound state's sub-state, the sub-state's params are restored from
  the last entry, not re-derived. The parent must supply matching params if it
  transitions to a history pseudostate that leads to a param-carrying sub-state.

- **Relationship to output events (US-1.16)**: State params and output events
  serve different purposes. State params are synchronous, pull-based (accessible
  as properties while in the state). Output events are push-based streams (emitted
  over time while in the state). Both can coexist on the same state.

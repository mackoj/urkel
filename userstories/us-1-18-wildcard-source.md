# US-1.18: Wildcard Source (`*`)

## Objective

Allow a caller-driven event to be handled from **any non-final state** with a single declaration, eliminating the need to repeat the same transition once per source state.

## Background

Events like `networkLost`, `sessionExpired`, or `forceStop` must be handled in every active state. Writing one transition per state is noise that buries the important logic:

```
# Without wildcard — repetitive and fragile (easy to miss a new state):
Connecting  -> networkLost -> Error
Active      -> networkLost -> Error
Reconnecting -> networkLost -> Error
Syncing     -> networkLost -> Error
```

`*` as the source state is syntactic sugar: it expands to one transition per non-final state at validation time. The meaning is identical to writing them out by hand.

`*` is a **scope modifier** — it applies only to caller-driven transitions. `@on` reactions (US-1.13) already have implicit any-state scope by default; `*` is not needed there.

## DSL Syntax

### Wildcard to a destination

```
machine NetworkSession<SessionContext>

@states
  init Idle
  state Connecting
  state Active
  state Reconnecting
  final Closed

@transitions
  Idle        -> connect     -> Connecting
  Connecting  -> established -> Active
  Active      -> disconnect  -> Idle
  Reconnecting -> retry      -> Connecting

  # From any non-final state: transition to Error
  * -> networkLost   -> Closed  / logDisconnect
  * -> sessionExpired -> Closed / clearSession
  * -> forceClose    -> Closed
```

### Wildcard internal (`* -*>`) — cross-cutting in-place handler

Combines `*` (any-state scope) with `-*>` (no exit/re-entry, US-1.8):

```
# Handle a heartbeat ping in any state without changing state or triggering lifecycle
* -*> ping / recordHeartbeat

# Log any analytics event from any state
* -*> logEvent(name: String) / forwardToAnalytics
```

### Wildcard with guard

```
# Expire the session from any state, but only if the token is actually expired
* -> sessionExpired [isTokenExpired] -> Closed / clearCredentials
* -> sessionExpired [else]           -> Active  / refreshToken
```

### Wildcard + specific override (precedence)

```
# General rule: any state → Error on network loss
* -> networkLost -> Error / logError

# Specific override: while Syncing, network loss is recoverable
Syncing -> networkLost -> Reconnecting / scheduleRetry
```

When the machine is in `Syncing` and `networkLost` fires, the specific `Syncing` transition takes precedence over the wildcard.

## Acceptance Criteria

* **Given** `* -> networkLost -> Error`, **when** the machine is in any non-final state and `networkLost` fires, **then** it transitions to `Error`.

* **Given** `* -> event -> Dest`, **when** processed, **then** the wildcard expands to one transition per non-final source state — semantically identical to writing each explicitly.

* **Given** both `* -> networkLost -> Error` and `Active -> networkLost -> Reconnecting`, **when** the machine is in `Active` and `networkLost` fires, **then** the **specific** transition takes precedence over the wildcard.

* **Given** a wildcard whose expansion includes a state that already has an explicit transition for the same event, **when** validated, **then** a **warning** is emitted noting the shadowed states — the specific transition takes precedence and the wildcard is silently suppressed for that state.

* **Given** `* -*> event / action` (wildcard internal), **when** processed, **then** it expands to one internal transition per non-final source state; no exit/re-entry occurs in any of them (US-1.8).

* **Given** `* -> event -> Dest` where `Dest` is a `final` state, **when** processed, **then** it is valid — a wildcard may target a final state.

* **Given** `* -> event -> *` (wildcard destination), **when** validated, **then** an error is emitted: `"'*' is not valid as a transition destination"`.

* **Given** a wildcard transition that would expand to zero states (all states are `final`), **when** validated, **then** a warning is emitted: `"Wildcard transition for 'event' matches no non-final states"`.

* **Given** `@on BLE::X` with `*` as a source, **when** validated, **then** an error is emitted: `"'*' source is not valid on '@on' reactions — '@on' already applies from any parent state"`.

## Grammar

```ebnf
TransitionSource ::= Identifier | "*"
TransitionStmt   ::= TransitionSource TransitionArrow EventDecl GuardClause? (TransitionArrow Identifier)? ActionClause? Newline
```

`*` is only valid as a `TransitionSource` on regular `@transitions` lines. It is not valid as a destination, and not valid in `@on` declarations.

## Relationship to `@on`

`*` and `@on` are **not alternatives** — they operate in different trigger domains:

| | `* -> event -> Dest` | `@on Machine::State -> Dest` |
|--|---|---|
| **What triggers it** | Caller sends `event` | Sub-machine enters a state |
| **From which parent states** | Any non-final (expanded) | Any non-final (implicit) |
| **Who controls when it fires** | External caller | Internal sub-machine |

`@on` does not need `*` because any-state scope is its default. `*` does not replace `@on` because the trigger source is different.

## Notes

- `*` is pure syntactic sugar. Its only effect is to avoid repetition — there is no runtime behavior that differs from writing each transition explicitly.
- Wildcards do **not** expand to `final` states — final states cannot be transition sources.
- Specific transitions always shadow wildcards for the same `(state, event)` pair. This is resolved at validation time: the wildcard expansion simply skips any state that has an explicit transition for the same event.
- For the effect modifier that suppresses exit/re-entry, see `-*>` (US-1.8). `*` and `-*>` are orthogonal and combine freely: `* -*> event / action`.

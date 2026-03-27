# US-1.8: Internal Transitions and Wildcard Source

## Objective

Introduce two shorthand constructs that eliminate common boilerplate:

- **Internal transitions** (`-*>`) — handle an event without exiting or re-entering the current state.
- **Wildcard source** (`*`) — handle an event from any non-final state with a single declaration.

## Background

Two patterns appear in almost every real-world machine:

1. **Self-contained updates** — the machine handles an event (a progress tick, a seek command, a UI update) but should not leave its current state. Writing `Playing -> seek -> Playing` works but triggers exit and re-entry — firing exit/entry actions and resetting any associated timers. `-*>` expresses "handle this event, stay here, don't re-enter."

2. **Cross-cutting events** — events like `networkLost`, `sessionExpired`, or `forceStop` must be handled in every active state. Writing one transition per state (`StateA -> networkLost -> Error`, `StateB -> networkLost -> Error`, …) is noise. A single `* -> networkLost -> Error` expresses the intent cleanly.

Both constructs keep the arrow syntax DNA of Urkel intact.

## DSL Syntax

### Internal transitions (`-*>`)

```
machine VideoPlayer: PlayerContext

@states
  init Idle
  state Playing
  state Paused
  final Stopped

@transitions
  Idle    -> play(url: URL)         -> Playing
  Playing -> pause                  -> Paused
  Paused  -> resume                 -> Playing
  Playing -> stop                   -> Stopped

  # Internal: stay in Playing, no exit/re-entry, action fires
  Playing -*> seek(position: Double)        / emitSeekUI
  Playing -*> updateProgress(pct: Double)   / updateProgressBar

  # Internal with guard
  Playing -*> adjustVolume(level: Float) [isVolumePermitted] / applyVolume
```

### Wildcard source (`*`)

```
machine NetworkSession: SessionContext

@states
  init Idle
  state Connecting
  state Active
  state Reconnecting
  final Closed

@transitions
  Idle        -> connect    -> Connecting
  Connecting  -> established -> Active
  Active      -> disconnect  -> Idle
  Reconnecting -> retry      -> Connecting

  # Wildcard: networkLost transitions from any non-final state to Reconnecting
  * -> networkLost                -> Reconnecting  / logDisconnect
  * -> sessionExpired             -> Closed        / clearSession
  * -> forceClose                 -> Closed
```

### Combining both

```
# Internal wildcard: handle an event in any state without changing state
# (useful for cross-cutting logging or metrics)
* -*> ping / recordHeartbeat
```

## Acceptance Criteria

**Internal transitions (`-*>`)**

* **Given** `Playing -*> seek(position: Double)`, **when** the `seek` event fires, **then** the machine remains in `Playing` — no state type change occurs.

* **Given** an internal transition with an action, **when** the event fires, **then** the action is invoked; `@entry` and `@exit` actions for the current state do **not** fire.

* **Given** an internal transition with a destination state (`Playing -*> seek -> Paused`), **when** validated, **then** an error is emitted: `"Internal transition '-*>' must not specify a destination state"`.

* **Given** an internal transition on a `final` state, **when** validated, **then** an error is emitted: `"Final states cannot have transitions"`.

**Wildcard source (`*`)**

* **Given** `* -> networkLost -> Error`, **when** the machine is in any non-final state and `networkLost` fires, **then** it transitions to `Error`.

* **Given** both `* -> networkLost -> Error` and `Active -> networkLost -> Reconnecting`, **when** the machine is in `Active` and `networkLost` fires, **then** the specific transition (`Active -> networkLost -> Reconnecting`) takes precedence over the wildcard.

* **Given** a wildcard transition where the `*` expansion would include a state that already has an explicit transition for the same event, **when** validated, **then** a **warning** is emitted noting the shadowed states (but processing continues).

* **Given** `* -> event -> Dest` where `Dest` is a valid state, **when** processed, **then** the wildcard expands to one transition per non-final source state.

* **Given** a wildcard internal transition `* -*> event / action`, **when** processed, **then** it expands to one internal transition per non-final source state.

## Grammar

```ebnf
TransitionStmt  ::= TransitionSource TransitionArrow EventDecl GuardClause? (TransitionArrow Identifier)? ActionClause? Newline
TransitionSource ::= Identifier | "*"
TransitionArrow  ::= "->" | "-*>"
```

When the arrow is `-*>`, the `TransitionArrow Identifier` (destination) segment is omitted.

## Notes

- Internal transitions with guards follow the same guard rules as regular transitions (US-1.6).
- Wildcards do **not** match `final` states — final states cannot have outgoing transitions.
- Specific transitions always shadow wildcards for the same `(state, event)` pair. This precedence is resolved at validation time, not at runtime.

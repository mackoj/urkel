# US-1.8: Internal Transitions (`-*>`)

## Objective

Introduce the `-*>` arrow as a **cross-cutting effect modifier**: handle an event without exiting or re-entering the current state, suppressing entry and exit action firing. Unlike a self-transition (`-> SameState`), `-*>` leaves the machine's state unchanged in every sense — no lifecycle hooks, no timer resets, no re-entry.

## Background

The machine handles an event (a seek command, a progress tick, a volume change) but should not leave its current state. Writing `Playing -> seek -> Playing` is a self-transition — it exits and re-enters `Playing`, firing `@exit`/`@entry` actions and resetting any `after(duration)` timers on that state. This is semantically wrong for in-place updates.

`-*>` expresses precisely: "handle this event, stay here, do not re-enter." It is not a "type of transition" — it is a **modifier on the arrow** that suppresses exit and re-entry. It can appear anywhere an arrow can:

- On a regular caller-driven transition: `State -*> event / action`
- On a wildcard caller-driven transition: `* -*> event / action` (US-1.18)
- On a reactive `@on` subscription: `@on BLE::X -*> / action` (US-1.13)
- On an eventless `always` with action only: `State -*> always [guard] / action` (US-1.9)

## DSL Syntax

### In-place handler (`-*>` with action)

The caller sends the event; the machine handles it in-place and runs the action. No exit, no re-entry.

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

  # In-place handler: caller → machine; action fires, state stays
  Playing -*> seek(position: Double)        / emitSeekUI
  Playing -*> updateProgress(pct: Double)   / updateProgressBar

  # In-place handler with guard
  Playing -*> adjustVolume(level: Float) [isVolumePermitted] / applyVolume
```

### Output event (`-*>` without action)

The machine emits this event to the caller while staying in the state. No action is needed — the generator wires these up as a stream of values the caller can observe. See [US-1.16](us-1-16-continuation-transitions.md) for the full stream production pattern.

```
@entry Running / startWatching
@exit  Running / stopWatching

Running -*> directoryChanged(event: DirectoryEvent)   # output: machine → caller
Running -*> watchWarning(error: Error) / logWarning   # in-place handler: action present
Running -> watchFailed(error: Error) -> Error
```

The two forms at a glance:

| Form | Direction | Action? | Meaning |
|------|-----------|---------|---------|
| `State -*> event(p) / action` | Caller → machine | Yes | In-place handler |
| `State -*> event(p)` | Machine → caller | No | Output event → stream |

## Acceptance Criteria

* **Given** `Playing -*> seek(position: Double)`, **when** the `seek` event fires, **then** the machine remains in `Playing` — no state type change occurs.

* **Given** a state with `@entry`/`@exit` actions and an internal transition on it, **when** the internal transition fires, **then** neither `@exit` nor `@entry` fire — the state is not exited or re-entered.

* **Given** a state with an `after(duration)` timer and an internal transition on it, **when** the internal transition fires, **then** the timer is **not** reset — it continues counting from when the state was entered.

* **Given** an internal transition with an action (`-*> event / action`), **when** the event fires, **then** the action is invoked.

* **Given** `Playing -*> seek(position: Double) -> Paused` (destination specified on `-*>`), **when** validated, **then** an error is emitted: `"'-*>' must not specify a destination state"`.

* **Given** an internal transition on a `final` state, **when** validated, **then** an error is emitted: `"Final states cannot have transitions"`.

* **Given** `Running -*> directoryChanged(event: DirectoryEvent)` with no action, **when** processed, **then** it is recognized as an **output event**: the generator creates a typed stream for `DirectoryEvent` accessible from the machine while in `Running`.

* **Given** an internal transition with no action and **no parameters** (`State -*> reset`), **when** validated, **then** a warning is emitted: `"'-*>' on event 'reset' has no action and no parameters — it silently consumes the event without producing data; add an action or parameters"`.

* **Given** an output event declaration on a `final` state, **when** validated, **then** an error is emitted: `"Final states cannot declare output events"`.

## Relationship to `->` (self-transition)

The difference between `-*>` and `-> SameState` matters only when the state has lifecycle hooks:

```
# Self-transition: exits and re-enters Playing
# → @exit Playing fires, then @entry Playing fires
# → after(duration) timers reset
Playing -> seek(position: Double) -> Playing / emitSeekUI

# Internal transition: stays in Playing
# → @exit and @entry do NOT fire
# → after(duration) timers are NOT reset
Playing -*> seek(position: Double) / emitSeekUI
```

Without `@entry`/`@exit` actions and without `after(duration)` timers, they are semantically equivalent. **Prefer `-*>` when the intent is "handle this event in-place with no lifecycle effects".**

## Grammar

```ebnf
TransitionStmt  ::= TransitionSource TransitionArrow EventDecl GuardClause? (TransitionArrow Identifier)? ActionClause? Newline
TransitionArrow ::= "->" | "-*>"
TransitionSource ::= Identifier | "*"
```

When the arrow is `-*>`, the destination `(TransitionArrow Identifier)` is omitted. `-*>` is valid with any `TransitionSource` — including `*` (US-1.18).

## Notes

- `-*>` is purely an effect modifier. It is not a separate kind of transition. The same `-*>` arrow appears in `@on` reactions (US-1.13), wildcard transitions (US-1.18), and eventless `always` (US-1.9).
- Internal transitions with guards follow the same rules as regular transitions (US-1.6): `Playing -*> seek [canSeek] / emitSeek`.
- For wildcard scope (`*` source), see US-1.18.

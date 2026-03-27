# US-1.12: Parallel Regions

## Objective

Allow a machine to model multiple independent, simultaneously active sub-states using orthogonal regions — and react to individual region state changes or to the completion of all regions using the same `@on` notation introduced for composed machines (US-1.13).

## Background

Some concerns within a single machine are genuinely independent and must be tracked at the same time. A media player has both a **playback state** (Playing/Paused) and a **network quality state** (Auto/HD/SD) that are orthogonal: you can be paused on HD or playing on SD. These should not be two separate machines, because they belong to the same coherent object and the combined state matters.

XState calls these **parallel states**. Harel's original formalism calls them **orthogonal components**. In Urkel they are declared with `@parallel`, which introduces a named block containing two or more `region` sub-declarations. Each region is an independent sub-machine with its own `init` states. Events are dispatched to all active regions simultaneously; a region silently ignores events it has no transition for.

This is distinct from `@import`/fork (US-1.13), which spawns a **separate** machine with its own lifetime. `@parallel` models **intra-machine** concurrency: all regions share the machine's lifetime, the combined state is a product of all active region states, and they terminate together.

### Consistency with `@on`

Reacting to parallel region state changes uses the same `@on` syntax as composed machine subscriptions (US-1.13), with one structural difference in the path:

| Target | Syntax |
|--------|--------|
| Composed machine state | `@on MachineName::State` |
| Parallel region state | `@on ParallelName.RegionName::State` |
| All regions completed | `@on ParallelName::done` |

The `::` always marks the **state reference boundary**. The left side is the path to the machine or region (using `.` for intra-machine navigation); the right side is the state name or keyword.

## DSL Syntax

### Basic parallel declaration

```
machine StreamingPlayer: PlayerContext

@states
  init Idle
  @parallel ActiveSession
    region Playback
      init Playing
      state Paused
      final PlaybackDone
    region Quality
      init Auto
      state HD
      state SD
  final Closed

# React to individual region state changes
@on ActiveSession.Playback::Paused   -*> / showPauseOverlay
@on ActiveSession.Playback::Playing  -*> / hidePauseOverlay
@on ActiveSession.Quality::HD        -*> / enableHDBadge
@on ActiveSession.Quality::Auto      -*> / disableHDBadge

# React when a specific region reaches its final state
@on ActiveSession.Playback::final    -> Closed / savePosition

# React when ALL regions have reached their final states
@on ActiveSession::done -> Closed

@transitions
  Idle -> start -> ActiveSession    # enters all regions at their init simultaneously

  # Region-internal transitions use dot notation: ParallelBlock.Region.State
  ActiveSession.Playback.Playing -> pause   -> ActiveSession.Playback.Paused
  ActiveSession.Playback.Paused  -> resume  -> ActiveSession.Playback.Playing
  ActiveSession.Quality.Auto     -> forceHD -> ActiveSession.Quality.HD
  ActiveSession.Quality.HD       -> fallback -> ActiveSession.Quality.Auto

  # Exit the whole parallel block at once
  ActiveSession -> stop -> Closed
```

### Actions and transitions in `@on` reactions

```
# Internal reaction only (no state change)
@on ActiveSession.Playback::Paused -*> / notifyPause

# Transition with action
@on ActiveSession.Quality::HD -> Active / enableHDMode

# Named handler, then transition
@on ActiveSession.Playback::PlaybackDone -> handleDone -> Reviewing

# Wildcard: any state change in a region — useful for logging/tracing
@on ActiveSession.Quality::* -*> / logQualityChange
```

### Full example: session with auth and presence regions

```
machine Messenger: MessengerContext

@states
  init Connecting
  @parallel Session
    region Auth
      init Authenticated
      state TokenRefreshing
      final Expired
    region Presence
      init Online
      state Away
      state Busy
      final Offline
  final Disconnected

# Region reactions
@on Session.Auth::TokenRefreshing -*> / showRefreshingBadge
@on Session.Auth::Expired         -> Disconnected / clearCredentials
@on Session.Presence::Away        -*> / updatePresenceIndicator
@on Session.Presence::Busy        -*> / updatePresenceIndicator

# Completion
@on Session::done -> Disconnected

@transitions
  Connecting -> established    -> Session
  Session    -> disconnect     -> Disconnected
  Session.Presence.Online -> setAway  -> Session.Presence.Away
  Session.Presence.Away   -> setOnline -> Session.Presence.Online
  Session.Presence.Online -> setBusy  -> Session.Presence.Busy
  Session.Auth.Authenticated -> refreshToken -> Session.Auth.TokenRefreshing
  Session.Auth.TokenRefreshing -> tokenRefreshed -> Session.Auth.Authenticated
```

## Acceptance Criteria

### Structure

* **Given** `@parallel Name` with two or more `region` blocks, **when** a transition targets the parallel state, **then** all regions are entered simultaneously and each region's `init` state is activated.

* **Given** fewer than two `region` blocks within a `@parallel` declaration, **when** validated, **then** an error is emitted: `"@parallel requires at least two regions"`.

* **Given** a `region` block missing an `init` child state, **when** validated, **then** an error is emitted: `"Region 'X' in '@parallel Y' must declare an 'init' state"`.

* **Given** duplicate state names across regions within the same `@parallel` block, **when** validated, **then** an error is emitted: `"Ambiguous state name 'X': used in multiple regions of '@parallel Y'"`.

### Event dispatch

* **Given** an event handled in one region but not another, **when** the machine receives it, **then** only the handling region transitions; the other remains unchanged.

* **Given** an event handled by multiple regions, **when** the machine receives it, **then** all matching regions transition simultaneously.

* **Given** a transition targeting the parallel block name (`-> ActiveSession`), **when** taken, **then** all regions enter their `init` states.

* **Given** a transition originating from the parallel block name (`ActiveSession -> stop -> Closed`), **when** the machine is in any combination of region states, **then** the transition fires and exits the entire block.

### `@on` region subscriptions

* **Given** `@on ActiveSession.Playback::Paused -*> / action`, **when** the `Playback` region enters `Paused`, **then** `action` fires and the parent does not change state.

* **Given** `@on ActiveSession.Quality::HD -> Active`, **when** the `Quality` region enters `HD`, **then** the parent transitions to `Active`.

* **Given** `@on ActiveSession.Playback::final -> Closed`, **when** the `Playback` region enters **any** of its final states, **then** the parent transitions to `Closed`.

* **Given** `@on ActiveSession::done -> Closed`, **when** **all** regions within `ActiveSession` have reached a final state, **then** the parent transitions to `Closed`.

* **Given** `@on ActiveSession::done` and one region is in a final state but another is not, **when** the first region enters its final state, **then** `done` does **not** fire — all regions must be final simultaneously.

* **Given** `@on ActiveSession.Playback::*  -*> / log`, **when** the `Playback` region enters **any** state, **then** `log` fires; the parent does not change state.

* **Given** `@on ActiveSession.Playback::UnknownState` where `UnknownState` is not declared in the `Playback` region, **when** validated, **then** an error is emitted: `"State 'UnknownState' does not exist in region 'Playback' of '@parallel ActiveSession'"`.

* **Given** `@on ActiveSession.UnknownRegion::Playing` where `UnknownRegion` is not a region of `ActiveSession`, **when** validated, **then** an error is emitted: `"'UnknownRegion' is not a region of '@parallel ActiveSession'"`.

* **Given** `@on` referencing a parallel block not declared in `@states`, **when** validated, **then** an error is emitted: `"'ActiveSession' is not a declared @parallel block"`.

* **Given** both `@on ActiveSession.Quality::HD` and `@on ActiveSession.Quality::*`, **when** the `Quality` region enters `HD`, **then** the specific subscription takes **precedence** over the wildcard.

## Grammar

```ebnf
ParallelDecl     ::= "@parallel" Identifier Newline (Indent RegionDecl+ Dedent)
RegionDecl       ::= "region" Identifier Newline (Indent StateStmt+ Dedent)

OnDecl           ::= "@on" OnTarget ("->" (Identifier "->")? Identifier ActionClause?
                                    | "-*>" ActionClause) Newline
OnTarget         ::= MachineStateRef | ParallelStateRef | ParallelDoneRef
MachineStateRef  ::= Identifier "::" StateRef
ParallelStateRef ::= Identifier "." Identifier "::" StateRef
ParallelDoneRef  ::= Identifier "::" "done"
StateRef         ::= "init" | "final" | "*" | Identifier
```

`@on` declarations appear at the top level alongside `@entry`/`@exit`, outside `@states` and `@transitions`.

## Notation summary

| Syntax | Meaning |
|--------|---------|
| `@on P.Region::State` | Region enters a specific state |
| `@on P.Region::init` | Region (re-)enters its `init` state |
| `@on P.Region::final` | Region enters **any** of its final states |
| `@on P.Region::*` | Region enters **any** state (broad wildcard) |
| `@on P::done` | **All** regions have reached a final state |
| `-> S` | Transition parent to `S` |
| `-> S / a` | Action `a`, transition parent to `S` |
| `-> a -> S` | Named handler `a`, transition parent to `S` |
| `-*> / a` | Action `a`, parent stays in current state |

## Notes

- `@parallel` regions are intra-machine — they are part of the same machine's state space, not separate machines. This is why navigation uses `.` (intra-machine) while `::` marks only the state reference boundary, consistent with US-1.13.
- Unlike `@import`/fork (US-1.13), parallel regions are not independently addressable as separate machines and cannot be subscribed to from another machine's `@on`.
- Each region may itself contain compound states with nesting and history (US-1.10, US-1.11).
- The combined state of all active regions is a product type — `(PlaybackState, QualityState)` — not a sum type.

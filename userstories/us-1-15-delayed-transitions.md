# US-1.15: Delayed Transitions

## Objective

Allow a transition to fire automatically after a specified duration if the machine has not already left the current state — without any external event.

## Background

Almost every real state machine has at least one timeout: a connection attempt that fails after 30 seconds, a session that expires after 30 minutes, a spinner that gives up after 10 seconds. Without explicit DSL support, developers write manual timers inside injected closures. This works but makes the timeout invisible to the DSL, the visualizer, the simulator, and the test stub generator.

`after(duration)` is syntactic sugar for a self-cancelling timer: when the machine enters the state, a timer starts. If the timer fires before any other transition leaves the state, the machine transitions to the target. If any other transition fires first, the timer is cancelled.

Duration is specified inline with a numeric literal and a unit: `after(500ms)`, `after(30s)`, `after(5min)`.

## DSL Syntax

```
machine ConnectionManager<ConnectionContext>

@states
  init Idle
  state Connecting
  state Active
  state Reconnecting
  state TimedOut
  final Closed

@transitions
  Idle        -> connect                  -> Connecting
  Connecting  -> established              -> Active
  Connecting  -> failed                   -> Reconnecting
  Active      -> disconnected             -> Reconnecting
  Reconnecting -> retry                   -> Connecting

  # Automatic timeout transitions
  Connecting   -> after(10s)              -> TimedOut
  Reconnecting -> after(30s)              -> TimedOut

  TimedOut -> giveUp -> Closed
  Active   -> close  -> Closed
```

### With action on timeout

```
@transitions
  Loading -> after(5s) -> Error / logTimeout
```

### With guard on timeout

```
@transitions
  # Only time out if the retry budget is exhausted
  Reconnecting -> after(30s) [retriesExhausted] -> Closed / logFinalTimeout
  Reconnecting -> after(30s) [else]             -> Connecting
```

### Multiple durations on the same state

```
@transitions
  Idle -> after(30s)  -> Warning     # first timeout: show warning
  Idle -> after(60s)  -> AutoLogout  # second timeout: force logout
```

## Acceptance Criteria

* **Given** `State -> after(30s) -> Target`, **when** the machine enters `State` and no transition fires within 30 seconds, **then** the machine automatically transitions to `Target`.

* **Given** `State -> after(30s) -> Target`, **when** another transition fires before 30 seconds elapse, **then** the pending timer is cancelled and `Target` is never reached via the timeout.

* **Given** multiple `after` transitions on the same state with different durations, **when** the machine enters the state, **then** all timers start simultaneously; the first to fire triggers its respective transition; subsequent timers are cancelled.

* **Given** duration literals, **when** parsed, **then** the following units are accepted: `ms` (milliseconds), `s` (seconds), `min` (minutes).

* **Given** `after(0s)` or a negative duration, **when** validated, **then** an error is emitted: `"Delayed transition duration must be positive"`.

* **Given** `after(duration)` with parameters (`after(30s, reason: String)`), **when** validated, **then** an error is emitted: `"Delayed transitions cannot carry parameters"`.

* **Given** a guard on a delayed transition (`after(30s) [guard] -> Dest`), **when** the timer fires and the guard returns `false`, **then** the transition does not occur — the machine remains in the state and the timer does not restart.

* **Given** a delayed transition on a `final` state, **when** validated, **then** an error is emitted: `"Final states cannot have transitions"`.

## Grammar

```ebnf
EventDecl  ::= Identifier ("(" ParameterList ")")? | AfterEvent | "always"
AfterEvent ::= "after" "(" Duration ")"
Duration   ::= Number DurationUnit
DurationUnit ::= "ms" | "s" | "min"
```

`after(...)` in the event position is treated as a reserved event form. It takes no parameters beyond the duration literal.

## Notes

- Delayed transitions, like `@invoke` (US-1.14), require the runtime to manage a timer lifecycle. The DSL declares the intent; the implementation is injected via a clock dependency.
- In tests, a controllable clock dependency can be substituted to trigger timeouts synchronously — no real waiting required.
- A `after(duration)` on a state with `@invoke` (US-1.14) acts as a timeout for the invocation: if the service does not complete before the timer fires, the delayed transition takes over.

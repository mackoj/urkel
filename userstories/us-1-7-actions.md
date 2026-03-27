# US-1.7: Actions

## Objective

Allow transitions and state boundaries to declare named side effects — fire-and-forget callbacks whose implementations live in the host language and are injected at construction time.

## Background

Transitions and states often need to trigger work that doesn't change the machine's state: logging, analytics, UI updates, emitting events to other systems. These side effects are **actions**.

Like guards (US-1.6), action names are declared in the DSL and implemented in the host language. This keeps the DSL as a pure structural description while making every side effect visible to readers, visualizers, and simulators.

Three attachment points exist:

- **Transition actions** — written inline after the destination with `/`. They fire when the specific transition is taken.
- **Entry actions** — declared with `@entry StateName / action`. They fire whenever any transition arrives at that state.
- **Exit actions** — declared with `@exit StateName / action`. They fire whenever any transition departs from that state.

Actions do not affect control flow — they cannot prevent a transition or change its destination. For conditional branching, use guards (US-1.6).

## DSL Syntax

```
machine MediaPlayer: PlayerContext

@states
  init Idle
  state Loading
  state Playing
  state Paused
  final Stopped

# Entry and exit actions are declared at the top level, outside @states/@transitions
@entry Loading / showSpinner
@exit  Loading / hideSpinner

@entry Playing / startAnalytics, resumeHeartbeat
@exit  Playing / stopAnalytics, pauseHeartbeat

@transitions
  # Transition actions come after the destination, prefixed with /
  Idle    -> load(url: URL)  -> Loading  / logLoadRequest
  Loading -> ready           -> Playing  / hideSpinner, trackPlayStart
  Playing -> pause           -> Paused
  Paused  -> resume          -> Playing
  Playing -> stop            -> Stopped  / logPlaybackComplete
  Paused  -> stop            -> Stopped  / logPlaybackComplete
```

### Multiple transition actions

```
@transitions
  Idle -> submit -> Processing / validate, logSubmit, trackConversion
```

### Guard + action on the same transition

```
@transitions
  Cart -> checkout [hasPaymentMethod]  -> Processing / chargeCard, logCheckout
  Cart -> checkout [!hasPaymentMethod] -> Error      / logNoPayment
```

## Acceptance Criteria

* **Given** `-> Dest / actionName`, **when** the transition is taken, **then** `actionName` is invoked after the state change.

* **Given** `-> Dest / action1, action2, action3`, **when** the transition is taken, **then** actions are invoked in **declaration order** (left to right).

* **Given** `@entry StateName / action`, **when** any transition arrives at `StateName`, **then** the entry action fires. If multiple transitions arrive at the same state, the entry action fires once per transition taken.

* **Given** `@exit StateName / action`, **when** any transition departs from `StateName`, **then** the exit action fires before the state is consumed.

* **Given** a state with both entry and exit actions and a self-transition on that state, **when** the self-transition fires, **then** the exit action fires first (leaving), then the entry action fires (re-entering).

* **Given** `@entry StateName / a, b`, **when** processed, **then** multiple entry actions are accepted and invoked in declaration order.

* **Given** `@entry StateName / action` where `StateName` does not appear in `@states`, **when** validated, **then** an error is emitted: `"@entry references unknown state 'StateName'"`.

* **Given** the same `@entry StateName` declared twice, **when** validated, **then** an error is emitted: `"Duplicate @entry for state 'StateName'"`.

* **Given** an action name declared in the DSL but not present in the machine's injected dependencies, **when** validated at the semantic level, **then** an error is emitted naming the missing action.

* **Given** an internal transition (`-*>`, US-1.8) with an action, **when** the transition fires, **then** the action is invoked but entry/exit actions do **not** fire (internal transitions do not re-enter the state).

## Grammar

```ebnf
TransitionStmt  ::= Identifier "->" EventDecl GuardClause? "->" Identifier ActionClause? Newline
ActionClause    ::= "/" Identifier ("," Identifier)*
LifecycleDecl   ::= ("@entry" | "@exit") Identifier ActionClause Newline
```

`LifecycleDecl` entries appear at the top level of the file alongside `@states` and `@transitions`, not nested inside them.

## Notes

- Actions are fire-and-forget: the DSL does not define their return type or whether they are synchronous or async. That is left to the host-language emitter.
- Entry/exit actions fire at the **parent** boundary for compound states (US-1.10), not at each child-to-child transition within the compound state.
- Actions are not guards: they cannot prevent a transition from firing. If you need conditional behavior, use a guard (US-1.6).

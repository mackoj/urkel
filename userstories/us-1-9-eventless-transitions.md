# US-1.9: Eventless Transitions

## Objective

Allow transitions that fire automatically on state entry — without any external event — enabling conditional routing and reactive state evaluation.

## Background

Eventless transitions (sometimes called "automatic" or "always" transitions) model conditions that must be checked immediately when a state is entered. They differ fundamentally from guards (US-1.6): a guard prevents an event-triggered transition from firing; an `always` transition fires on its own as soon as its state is entered (if the guard is true, or unconditionally if there is no guard).

Two patterns need this:

1. **Conditional routing** — a transient state that immediately fans out to one of several targets based on context. The caller never observes this state as a stable resting point; it is purely a branch node.

2. **Reactive re-evaluation** — a state that should re-check a condition continuously and leave as soon as the condition becomes true (e.g., `Idle` automatically transitioning to `Alert` the moment a threshold is crossed).

Urkel uses `always` as a reserved keyword in the event position of the standard transition arrow syntax. This keeps the flat table structure and makes eventless transitions visually obvious.

## DSL Syntax

```
machine Checkout: CheckoutContext

@states
  init Cart
  state Routing        # transient routing state
  state GuestCheckout
  state MemberCheckout
  state Processing
  final Complete

@transitions
  Cart -> proceed -> Routing

  # Routing is a transient state — always transitions fan out based on context
  Routing -> always [isMember]   -> MemberCheckout
  Routing -> always [!isMember]  -> GuestCheckout

  MemberCheckout -> confirm -> Processing
  GuestCheckout  -> confirm -> Processing
  Processing     -> paid    -> Complete
```

### Unguarded `always` (unconditional, always transient)

```
@states
  init Boot
  state Dashboard

@transitions
  # Boot is entered and immediately transitions to Dashboard — no event required
  Boot -> always -> Dashboard
```

### `always` as a reactive condition (with action but no state change)

```
@transitions
  # While Active, if the session expires, fire a side effect without changing state
  Active -*> always [isSessionExpired] / notifyExpiry
```

### Multiple ordered `always` on the same state

```
@transitions
  Validating -> always [isValid]        -> Submitting
  Validating -> always [hasWarnings]    -> SubmittingWithWarnings
  Validating -> always [else]           -> Invalid
```

## Acceptance Criteria

* **Given** `State -> always [guard] -> Dest`, **when** the machine enters `State` and the guard returns `true`, **then** the machine immediately and automatically transitions to `Dest` without any external event.

* **Given** `State -> always [guard] -> Dest`, **when** the guard returns `false` on entry, **then** the machine remains in `State` and waits for an explicit event.

* **Given** multiple `always` transitions on the same state, **when** the state is entered, **then** they are evaluated in **declaration order**; the first truthy branch is taken.

* **Given** `State -> always -> Dest` (unguarded), **when** the state is entered, **then** it immediately and unconditionally transitions to `Dest` — the state is **transient** and callers never observe it as a stable state.

* **Given** an unguarded `always` transition where source equals destination (`State -> always -> State`), **when** validated, **then** an error is emitted: `"Unguarded 'always' from 'State' to 'State' creates an infinite loop"`.

* **Given** `always` used as a user-defined event name elsewhere in the same file, **when** validated, **then** an error is emitted: `"'always' is a reserved event keyword"`.

* **Given** `always` with parameters (`always(param: Type)`), **when** validated, **then** an error is emitted: `"Eventless 'always' transitions cannot carry parameters"`.

* **Given** an `always` transition with no guard, no destination, and no action, **when** validated, **then** an error is emitted: `"Eventless transition must have a guard, a destination, or an action"`.

* **Given** a state has both `always` transitions and explicit-event transitions, **when** processed, **then** a **warning** is emitted if the unguarded `always` would shadow the explicit events (the explicit events could never be reached).

## Grammar

```ebnf
EventDecl   ::= Identifier ("(" ParameterList ")")? | "always"
```

`always` in the event position is a reserved keyword. It takes no parameters.

## Notes

- `always` transitions are evaluated synchronously on state entry, after any `@entry` actions (US-1.7).
- A state whose only outgoing transitions are unguarded `always` is considered **transient**: it is guaranteed to never be a stable resting state.
- For timed automatic transitions (fire after N seconds), see the delayed transitions story (US-1.15).

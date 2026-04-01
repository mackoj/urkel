# US-5.9: Eventless Transitions

## Objective

Emit correct Swift code for `always` transitions (US-1.9): fire automatically
on state entry without an explicit caller event. Unguarded `always` transitions
make a state *transient* — the machine immediately moves to the destination.
Guarded `always` transitions emit a `checkAlways()` method that callers invoke
after entering the state to trigger the auto-evaluation.

## Background

`always` in the event position means "fire this transition without waiting for an
event". Two patterns exist:

- **Unconditional `always`** — the state is purely a routing node; it immediately
  transitions to the destination. The emitter generates an `autoTransition()`
  convenience on the state's extension.
- **Guarded `always`** — `always [guard] -> Dest` — fires only when the guard is
  true. Multiple guarded `always` branches form a conditional dispatch.

In both cases, the emitter does NOT generate automatic async machinery (no
`Task`, no `didSet`). The DSL declares the *intent*; the runtime integration
decides *when* to call `autoTransition()`. Callers — typically an actor or
`@Observable` model — call it immediately after receiving the new machine phase.

## Input DSL

```
machine Checkout: CheckoutContext

@states
  init Cart
  state Routing
  state GuestCheckout
  state MemberCheckout
  state Processing
  final Complete

@transitions
  Cart -> proceed -> Routing

  Routing -> always [isMember]   -> MemberCheckout
  Routing -> always [!isMember]  -> GuestCheckout

  MemberCheckout -> confirm -> Processing
  GuestCheckout  -> confirm -> Processing
  Processing     -> paid    -> Complete
```

## Generated Output (delta)

```swift
extension CheckoutMachine where Phase == CheckoutPhase.Routing {
    /// Evaluates `always` guards and transitions automatically.
    /// Call this immediately after entering the `Routing` phase.
    public consuming func autoTransition() async throws -> CheckoutState {
        if await _isMember(_context) {
            let next = try await _toMemberCheckout(_context)
            return .memberCheckout(CheckoutMachine<CheckoutPhase.MemberCheckout>(
                _context: next, /* … */
            ))
        } else {
            let next = try await _toGuestCheckout(_context)
            return .guestCheckout(CheckoutMachine<CheckoutPhase.GuestCheckout>(
                _context: next, /* … */
            ))
        }
    }
}
```

For an **unconditional** `always`:

```swift
// Boot -> always -> Dashboard
extension AppMachine where Phase == AppPhase.Boot {
    /// Immediately transitions to `Dashboard`. Call after constructing the machine.
    public consuming func autoTransition() async throws -> AppMachine<AppPhase.Dashboard> {
        let next = try await _bootToDashboard(_context)
        return AppMachine<AppPhase.Dashboard>(_context: next, /* … */)
    }
}
```

Unconditional `always` returns a specific phase (single destination); guarded
`always` with multiple destinations returns `XxxState`.

## Acceptance Criteria

* **Given** `Routing -> always [isMember] -> MemberCheckout` and
  `Routing -> always [!isMember] -> GuestCheckout`, **when** emitted, **then**
  `CheckoutMachine<CheckoutPhase.Routing>` has `public consuming func
  autoTransition() async throws -> CheckoutState`.

* **Given** `Boot -> always -> Dashboard` (unconditional), **when** emitted,
  **then** the return type is the specific `AppMachine<AppPhase.Dashboard>` —
  not the combined state enum.

* **Given** `autoTransition()` with `[else]` as last guard, **when** emitted,
  **then** the `else` branch is a bare else clause with no guard check.

* **Given** a state that has BOTH normal caller-driven transitions AND an `always`
  transition, **when** validated (US-2.4), **then** a warning is already emitted;
  the emitter still generates both `autoTransition()` and the regular event
  methods — callers choose which to invoke.

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- Detect `always` transitions: `transition.event == .always`.
- Generate `autoTransition()` method on each state that has any `always`
  transitions.
- Reuse guard evaluation logic from US-5.7 (`if / else if / else` order).
- The transition closure name for `always` uses the state name:
  `_routingToMemberCheckout`, `_routingToGuestCheckout`, etc. — unique per
  `(source, destination)` pair to allow distinct implementations.

## Testing Strategy

* Snapshot-test `stateMachine` for the Checkout fixture extended with `always`.
* Assert `autoTransition()` exists on `Routing` extension.
* Assert `autoTransition()` return type is `CheckoutState` (multiple dests).
* Assert `autoTransition()` on `Boot` returns specific phase (one dest).
* Construct noop + call `autoTransition()` — assert falls through to `else`.

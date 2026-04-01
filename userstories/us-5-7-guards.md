# US-5.7: Guards

## Objective

Emit correct Swift code for guarded transitions (US-1.6): inject named boolean
predicates as closures, evaluate them in declaration order, and return the
**combined state enum** (not a specific phase type) from any transition that has
multiple possible destination phases. Single-destination guarded transitions
(where all branches converge on the same destination) may still return a specific
phase.

## Background

Guards fundamentally change the return type of a transition. An unguarded
`State -> event -> Dest` has one destination — the emitter can return
`XxxMachine<XxxPhase.Dest>`. A guarded pair:

```
State -> event [guard] -> Dest1
State -> event [else]  -> Dest2
```

can reach either `Dest1` or `Dest2`, so the emitter must return `XxxState` (the
combined state enum). This is intentional: the caller is forced to pattern-match,
making all branches explicit in application code.

## Input DSL

```
machine Checkout: CheckoutContext

@states
  init Cart
  state Processing
  state NoPaymentMethod
  state PaymentError
  final Complete

@transitions
  Cart -> checkout [hasPaymentMethod]  -> Processing      / chargeCard
  Cart -> checkout [!hasPaymentMethod] -> NoPaymentMethod

  Processing -> confirm [isCardValid]    -> Complete     / sendReceipt
  Processing -> confirm [isPayPalLinked] -> Complete     / sendReceipt
  Processing -> confirm [else]           -> PaymentError / logFailure

  PaymentError -> retry [canRetry] -> Processing
  PaymentError -> retry [else]     -> Cart            / clearCart
```

## Generated Output (delta)

Guard predicates join the machine struct:

```swift
public struct CheckoutMachine<Phase>: ~Copyable, Sendable {
    // … context, transition closures …

    // Guard predicates — evaluated in declaration order
    fileprivate let _hasPaymentMethod: @Sendable (CheckoutContext) async -> Bool
    fileprivate let _isCardValid:      @Sendable (CheckoutContext) async -> Bool
    fileprivate let _isPayPalLinked:   @Sendable (CheckoutContext) async -> Bool
    fileprivate let _canRetry:         @Sendable (CheckoutContext) async -> Bool
}
```

A guarded transition returns `CheckoutState` (combined state enum), not a
specific phase:

```swift
extension CheckoutMachine where Phase == CheckoutPhase.Cart {
    /// Handles `checkout` with guards. Pattern-match the result for each branch.
    public consuming func checkout() async throws -> CheckoutState {
        if await _hasPaymentMethod(_context) {
            let next = try await _chargeCard(_context)
            return .processing(CheckoutMachine<CheckoutPhase.Processing>(
                _context: next, /* … closures … */
            ))
        } else {
            let next = try await _checkoutNoPayment(_context)
            return .noPaymentMethod(CheckoutMachine<CheckoutPhase.NoPaymentMethod>(
                _context: next, /* … closures … */
            ))
        }
    }
}

extension CheckoutMachine where Phase == CheckoutPhase.Processing {
    /// Handles `confirm` — three guards; `[else]` is the catch-all.
    public consuming func confirm() async throws -> CheckoutState {
        if await _isCardValid(_context) {
            let next = try await _sendReceipt(_context)
            return .complete(CheckoutMachine<CheckoutPhase.Complete>(
                _context: next, /* … closures … */
            ))
        } else if await _isPayPalLinked(_context) {
            let next = try await _sendReceiptPayPal(_context)
            return .complete(CheckoutMachine<CheckoutPhase.Complete>(
                _context: next, /* … closures … */
            ))
        } else {
            let next = try await _logFailure(_context)
            return .paymentError(CheckoutMachine<CheckoutPhase.PaymentError>(
                _context: next, /* … closures … */
            ))
        }
    }
}
```

> **`[!guard]` generation**: `[!hasPaymentMethod]` reuses the same predicate
> closure (`_hasPaymentMethod`) and negates it with `!`:
> `if !(await _hasPaymentMethod(_context))`.

## Acceptance Criteria

* **Given** `Cart -> checkout [hasPaymentMethod] -> Processing`, **when** emitted,
  **then** a `_hasPaymentMethod: @Sendable (Context) async -> Bool` closure
  property is generated on the machine struct.

* **Given** two guard branches on the same event (`[hasPaymentMethod]` and
  `[!hasPaymentMethod]`), **when** emitted, **then** only **one** predicate
  closure is generated (deduplication).

* **Given** a guarded transition with multiple possible destinations, **when**
  emitted, **then** the method return type is `XxxState` (the combined enum),
  **not** a specific phase type.

* **Given** `[else]` as the final branch, **when** emitted, **then** it is the
  `else` clause of the final `if` — not a guard check.

* **Given** multiple guards on the same event (`[isCardValid]`, `[isPayPalLinked]`,
  `[else]`), **when** emitted, **then** guards are evaluated with `if / else if /
  else` **in declaration order**.

* **Given** a guarded transition where all branches lead to the same destination,
  **when** emitted, **then** the return type is the specific phase (optimisation
  — no combined enum needed).

* **Given** `noop` client, **when** constructed, **then** all guard predicates
  default to `{ _ in false }`, causing every guarded transition to take the last
  branch.

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- Detect guard branches by grouping `TransitionStmt` by `(source, event)` and
  checking for non-nil `GuardClause`.
- When branches all share one destination: emit specific return type.
- When branches differ: emit `XxxState` return type.
- `[!guard]` generates `!(await _guardName(_context))` — same closure, negated.
- `[else]` always maps to the final bare `else { }` block.

## Testing Strategy

* Snapshot-test `stateMachine` for the Checkout fixture.
* Assert `_hasPaymentMethod` closure is in the struct (once).
* Assert `checkout()` return type is `CheckoutState`.
* Assert the generated body is `if await _hasPaymentMethod ... else ...`.
* Assert `confirm()` body is `if / else if / else` in declaration order.
* Assert noop guard predicates are `{ _ in false }`.
* Construct a noop Checkout, call `checkout()`, assert result is
  `.noPaymentMethod` (guard returns false → falls through to `[!guard]` branch).

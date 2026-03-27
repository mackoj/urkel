# US-1.6: Guards

## Objective

Allow transitions to be conditional — taken only when a named boolean predicate is true at runtime — and make every branch of a conditional transition explicit and readable in the DSL.

## Background

Unconditional transitions (US-1.1) always fire. Real machines frequently need branching: "only go to `Submitting` if the form is valid". Urkel models this with **guards** — named boolean predicates whose implementations live in the host language and are injected at construction time.

A core design goal is that **the failure path must be as explicit as the success path**. Most FSM tools leave the "what happens when the guard fails" implicit. Urkel provides three explicit mechanisms:

- **`[guardName]`** — fires when the predicate returns `true`.
- **`[!guardName]`** — syntactic sugar for the same predicate returning `false`. Reuses the same implementation, inverted.
- **`[else]`** — fires when no preceding guard on the same event matched. Explicitly marks the catch-all as intentional.

Guard names (not `else`) are part of the machine's contract: each unique name becomes an injectable predicate that receives the current context and returns a `Bool`.

## DSL Syntax

```
machine Checkout: CheckoutContext

@states
  init Cart
  state Processing
  state PaymentError
  state NoPaymentMethod
  final Complete

@transitions
  # Pattern A — positive + negated (same predicate, both branches explicit)
  Cart -> checkout [hasPaymentMethod]  -> Processing    / chargeCard
  Cart -> checkout [!hasPaymentMethod] -> NoPaymentMethod

  # Pattern B — multiple guards + explicit else
  Processing -> confirm [isCardValid]    -> Complete      / sendReceipt
  Processing -> confirm [isPayPalLinked] -> Complete      / sendReceipt
  Processing -> confirm [else]           -> PaymentError  / logFailure

  # Pattern C — binary branch (most common)
  PaymentError -> retry [canRetry]  -> Processing
  PaymentError -> retry [else]      -> Cart           / clearCart
```

### Single guarded transition (no failure branch)

The validator warns but does not error when a guarded transition has no explicit failure branch, because a deliberate "silently do nothing" might be intended. Suppress the warning with a comment.

```
# Warning suppressed — intentional no-op when guard fails
Playing -*> seek(position: Double) [isSeekable]
```

## Acceptance Criteria

* **Given** `State -> event [guard] -> Dest`, **when** the predicate returns `true`, **then** the transition to `Dest` fires.

* **Given** `State -> event [!guard] -> Dest`, **when** the predicate returns `false`, **then** the transition to `Dest` fires — reusing the same predicate implementation, inverted.

* **Given** multiple branches on the same `(source, event)` using `[guardA]`, `[guardB]`, and `[else]`, **when** the event fires, **then** guards are evaluated in **declaration order**; the first truthy branch is taken; `[else]` fires only if all preceding guards returned `false`.

* **Given** `[else]` appears before a `[guardName]` on the same `(source, event)`, **when** validated, **then** an error is emitted: `"[else] must be the last branch for event 'X' from 'Y'"`.

* **Given** a guarded transition where no branch covers the guard-false case (no `[!guard]` or `[else]`), **when** validated, **then** a **warning** is emitted: `"Event 'X' from 'Y' has no explicit failure branch"`.

* **Given** a `[!guardName]` where no corresponding `[guardName]` (or `[else]`) exists for the same event, **when** validated, **then** a **warning** is emitted (the positive case is unhandled).

* **Given** a guard name referenced in the DSL but not present in the machine's injected dependencies, **when** validated at the semantic level, **then** an error is emitted naming the missing guard.

* **Given** `[else]` used as the only branch for an event with no other guards, **when** validated, **then** a warning is emitted: `"[else] with no preceding guards is equivalent to an unconditional transition"`.

## Grammar

```ebnf
TransitionStmt ::= Identifier "->" EventDecl GuardClause? "->" Identifier Newline
GuardClause    ::= "[" GuardExpr "]"
GuardExpr      ::= "else" | "!"? Identifier
```

## Notes

- Guard names must be valid identifiers. `else` is a reserved keyword in this position — it cannot be used as a guard name.
- Guards on internal transitions (`-*>`, US-1.8) and eventless transitions (`always`, US-1.9) follow the same syntax and semantics.
- See US-1.7 for combining guards with actions on the same transition line.

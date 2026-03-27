# US-1.11: History States

## Objective

Allow a compound state to remember the last active child state and return to it when re-entered — instead of always starting from the initial child.

## Background

When a user navigates away from a multi-step wizard or a tabbed settings screen and then returns, the expected behavior is to resume where they left off — not restart from the beginning. History states model this intent explicitly.

History is declared as a modifier on the compound state itself, not as a pseudo-child. This keeps the `@states` block clean. Transitions that want to "return to where we were" use a `.History` qualified target.

Two depths exist:

- **Shallow history** (`@history`) — remembers the last **direct** child only.
- **Deep history** (`@history(deep)`) — remembers the last **active descendant** at every nesting level.

If no history has been recorded yet (first visit), the machine falls back to the normal initial child.

## DSL Syntax

```
machine Settings<SettingsContext>

@states
  init Overview
  state Payment @history       # shallow: remembers last direct child
    state Card
    state PayPal
    state BankTransfer
  state Profile
  state Wizard @history(deep)  # deep: remembers entire active subtree
    state StepOne
    state StepTwo
      state SubA
      state SubB
    state StepThree
  final Closed

@transitions
  Overview -> openPayment  -> Payment       # enters initial child (Card) on first visit
  Overview -> openWizard   -> Wizard        # enters StepOne on first visit

  # Re-enter at the last visited child
  Overview -> returnToPayment -> Payment.History
  Overview -> returnToWizard  -> Wizard.History

  Payment.Card        -> switchToPayPal   -> Payment.PayPal
  Payment.PayPal      -> switchToCard     -> Payment.Card
  Payment             -> back             -> Overview

  Wizard.StepOne      -> next             -> Wizard.StepTwo
  Wizard.StepTwo.SubA -> next             -> Wizard.StepTwo.SubB
  Wizard.StepTwo      -> next             -> Wizard.StepThree
  Wizard              -> cancel           -> Overview

  Overview -> close -> Closed
```

## Acceptance Criteria

* **Given** `state Payment @history` with children `Card` and `PayPal`, **when** the machine exits `Payment.PayPal` and later re-enters via `Payment.History`, **then** the machine enters `PayPal` — the last active direct child.

* **Given** the machine has **never** visited the `Payment` compound state before, **when** a transition targets `Payment.History`, **then** the machine enters the initial child (`Card`) — the fallback behavior.

* **Given** `state Wizard @history(deep)` with nested children, **when** the machine exits from `Wizard.StepTwo.SubB` and later re-enters via `Wizard.History`, **then** the machine enters `Wizard.StepTwo.SubB` — the full path is restored.

* **Given** `state Payment @history` (shallow), **when** the machine exits from `Payment.PayPal`, **then** re-entering via `Payment.History` returns to `PayPal` (the direct child) — not to nested children of `PayPal`.

* **Given** `Payment.History` as a transition target where `Payment` does not declare `@history`, **when** validated, **then** an error is emitted: `"State 'Payment' does not declare @history"`.

* **Given** `@history` on a non-compound state (no children), **when** validated, **then** an error is emitted: `"@history requires a compound state with at least one child"`.

* **Given** `@history` on a `final` state, **when** validated, **then** an error is emitted: `"Final states cannot declare @history"`.

* **Given** a plain re-entry to the parent (`-> Payment`, not `-> Payment.History`), **when** taken, **then** the machine enters the **initial child** (`Card`), regardless of history — `.History` must be explicitly requested.

## Grammar

```ebnf
StateStmt       ::= StateKind Identifier HistoryModifier? Newline (Indent StateStmt+ Dedent)?
HistoryModifier ::= "@history" ("(" "deep" ")")?

QualifiedTarget ::= Identifier ("." (Identifier | "History"))*
```

The `.History` suffix is only valid as a transition destination on a state that declares `@history`. The validator enforces this.

## Notes

- History is stored as part of the machine's runtime value. It travels through transitions correctly and is not global mutable state.
- Shallow history only remembers the last **direct** child — if the last active state was a deeply nested descendant, shallow history returns to the intermediate parent, not the leaf.
- Deep history records the full active path through all nesting levels below the `@history(deep)` state.
- History has no interaction with parallel regions (US-1.12) — each region tracks its own state independently.

# US-12.6: History States (`@history`)

## 1. Objective

Extend the `.urkel` DSL to support **history states** — a modifier on compound states that causes the machine to remember the last active child state and return to it when the parent state is re-entered, rather than always starting from the initial child.

## 2. Context

History states are a core Harel statechart concept. They solve a very common UX problem: a user navigates away from a compound state (e.g., a multi-tab Settings screen or a multi-step wizard) and later returns — the machine should resume where they left off, not restart from the beginning.

XState models this as a `hist` pseudostate (a special child state of type `'history'`). Transitions target `Parent.hist` to return to the remembered child. There are two variants:
- **Shallow history** — remembers the last direct child state only.
- **Deep history** — remembers the entire subtree (last active descendant at all nesting levels).

In Urkel, history is expressed as a **modifier on the compound state declaration** (`@history` or `@history(deep)`), not as a pseudostate child. This keeps the `@states` block flat and readable. Transitions use `StateName.History` as the target when they want to return to the remembered position.

## 3. Acceptance Criteria

* **Given** `state Payment @history` with children `Card` and `PayPal`, **when** the machine re-enters `Payment` via a transition targeting `Payment.History`, **then** it enters the last active child (`Card` or `PayPal`) rather than the initial child.

* **Given** the machine has never visited the `Payment` compound state before, **when** a transition targets `Payment.History`, **then** it falls back to the declared initial child (`Card`).

* **Given** `state Wizard @history(deep)` with nested children, **when** the machine re-enters via `Wizard.History`, **then** it restores the deepest previously active descendant (not just the top-level child).

* **Given** a shallow `@history` state, **when** the machine is inside `Payment.PayPal` and exits, **then** re-entering via `Payment.History` returns to `PayPal`, not to nested children of `PayPal`.

* **Given** a compound state without `@history`, **when** a transition targets `StateName.History`, **then** the semantic validator emits an error: `"State 'StateName' does not declare @history"`.

* **Given** a `@history` modifier on a non-compound state (no children), **when** the validator runs, **then** it emits an error: `"@history requires a compound state with at least one child"`.

* **Given** the Visualizer (US-13.1), **when** a compound state has `@history`, **then** a small `H` (shallow) or `H*` (deep) badge appears on the state container, consistent with standard statechart notation.

* **Given** the Simulate mode (US-13.2), **when** the machine exits a `@history` state and later re-enters via `.History`, **then** the simulator correctly restores the previously active child, and the history badge is highlighted to show the remembered state.

## 4. Implementation Details

* **DSL syntax:**
  ```
  @states
    state Payment @history              # shallow: remembers last direct child
      state Card
      state PayPal

    state Wizard @history(deep)         # deep: remembers entire subtree
      state StepOne
      state StepTwo
        state SubA
        state SubB

  @transitions
    Processing -> paymentFailed(error: Error) -> Payment.History
    Settings   -> back                         -> Wizard.History
  ```

* **grammar.ebnf — extend `StateDecl`:**
  ```ebnf
  StateDecl     ::= StateKind Identifier HistoryModifier? Newline (Indent StateDecl+ Dedent)?
  HistoryModifier ::= "@history" ("(" HistoryDepth ")")?
  HistoryDepth  ::= "deep"
  ```
  Default (no depth arg) = shallow.

* **AST** — `StateNode` gains `history: HistoryKind?` where `HistoryKind` is `.shallow` | `.deep`.

* **Transition target resolution** — `Payment.History` is a qualified target. The parser resolves `.History` as a special pseudotarget on any compound `@history` state. Stored in `TransitionNode.targetIsHistory: Bool`.

* **Semantic validator** — verify `.History` targets are only used on states declaring `@history`; verify `@history` is only on compound states.

* **SwiftCodeEmitter** — the generated machine stores a `var _historyState: String?` for each `@history` compound state (keyed by state name). On exit from a compound state with history, the emitter records the last active child name into the history slot. On entry via `.History`, it reads the slot to select the correct child (or falls back to initial). Deep history stores the full path of active states.

* **Runtime representation** — history slots are stored inside the `Machine<State>` value (as internal stored properties). They are part of the machine's value and travel through transitions correctly.

## 5. Testing Strategy

* Parser: `@history` with no depth (shallow); `@history(deep)`; `@history` on atomic state → error; `Parent.History` as transition target.
* Semantic validator: `.History` on non-`@history` state → error; `@history` on `final` → error.
* Emitter: first entry (no history) → goes to initial child; after visiting `PayPal` then re-entering via `.History` → goes to `PayPal`; deep history restores full subtree.
* Integration: compile a machine with both shallow and deep history. Add to `generatedSwiftCompiles`.
* Simulate mode: verify history badge shows remembered state after exit.
* Fixture: `CheckoutMachine` with `Payment @history` in `Tests/UrkelTests/Fixtures/`.

# US-12.1: Guards — Conditional Transitions

## 1. Objective

Extend the `.urkel` DSL and compiler to support **guard conditions** on transitions, allowing a transition to be taken only when a named boolean predicate evaluates to `true` at runtime — and making the **failure path explicit** through negated guards `[!guard]` and a dedicated `[else]` fallback keyword.

## 2. Context

Currently every transition in Urkel is unconditional — a given event from a given state always produces the same destination state. Real-world state machines frequently require branching based on runtime conditions (e.g., "only proceed to `Submitting` if the form is valid"). XState calls these **guards**; SCXML calls them **conditions**.

Guards in Urkel follow the same philosophy as the rest of the DSL: the name is declared in the `.urkel` file, but the implementation lives entirely in Swift, injected via the `Client` struct. This preserves compile-time safety while enabling conditional branching.

A critical design goal beyond basic guard support: **the failure path must be as explicit and readable as the success path.** In many FSM tools the "what happens when the guard fails" is left implicit — an unlabelled fallback that a reader has to infer. Urkel provides two explicit mechanisms:

- **`[!guardName]`** — negated guard. Syntactic sugar: reuses the same guard closure but fires when it returns `false`. Makes the "this is the failure branch" intent self-documenting without requiring a second named guard.
- **`[else]`** — explicit catch-all keyword. Fires when no preceding guard on the same event matched. Visually marks the last-resort branch as intentional, not accidental.

Both can be mixed freely on the same event with multiple branches.

This story covers the DSL syntax, AST extension, parser, semantic validator, and Swift emitter.

## 3. Acceptance Criteria

* **Given** `Idle -> load(url: URL) [isValidURL] -> Loading`, **when** the guard returns `true`, **then** the transition to `Loading` fires.

* **Given** `Idle -> load(url: URL) [!isValidURL] -> Error`, **when** the same `isValidURL` guard returns `false`, **then** the transition to `Error` fires — using the same underlying closure, inverted.

* **Given** a set of transitions on the same event using `[guardA]`, `[guardB]`, and `[else]`, **when** the event fires, **then** guards are evaluated in declaration order; the first truthy branch is taken; `[else]` fires only if all preceding guards were false.

* **Given** `[else]` appears before a `[guardName]` on the same event, **when** the validator runs, **then** it emits an error: `"[else] must be the last branch for event 'load'"` (an `[else]` followed by more guards would make those guards unreachable).

* **Given** a `.urkel` file where no branch covers the guard-false case (a guarded transition with no corresponding `[!guard]` or `[else]`), **when** the validator runs, **then** it emits a **warning**: `"Event 'load' from 'Idle' has no branch for when all guards fail — add [else] or [!isValidURL] to make the failure path explicit"`.

* **Given** a `.urkel` file referencing a guard name that is never injected, **when** the semantic validator runs, **then** it emits a clear diagnostic error naming the missing guard.

* **Given** a valid `.urkel` file with guards, **when** code is generated, **then** each unique guard name (not `[else]`) is surfaced as a `var guardName: @Sendable (ContextType) -> Bool` closure on the `Client`.

* **Given** the Visualizer (US-13.1), **when** transitions have guards, **then** each branch arrow is labelled with its guard expression (`[isValidURL]`, `[!isValidURL]`, or `[else]`), making all paths immediately visible in the diagram.

## 4. Implementation Details

* **DSL syntax** — all branches of the same event are visible, failure path is explicit:
  ```
  # Pattern A: positive + negated guard (same closure, inverted)
  Idle -> load(url: URL) [isValidURL]   -> Loading  / logLoad
  Idle -> load(url: URL) [!isValidURL]  -> Error    / logInvalidURL

  # Pattern B: multiple guards + explicit else fallback
  Payment -> confirm [isCardValid]      -> Processing  / chargeCard
  Payment -> confirm [isPayPalLinked]   -> Processing  / chargePayPal
  Payment -> confirm [else]             -> PaymentError / showNoMethod

  # Pattern C: single guard + else (most common — binary branch)
  Error -> retry [canRetry]             -> Loading
  Error -> retry [else]                 -> Stopped    / logExhausted
  ```

* **grammar.ebnf** — extend `GuardClause`:
  ```ebnf
  TransitionStmt ::= Identifier "->" EventDecl GuardClause? "->" Identifier ForkClause? ActionClause?
  GuardClause    ::= "[" GuardExpr "]"
  GuardExpr      ::= "else" | "!"? Identifier
  ```

* **AST** — `TransitionNode` gains:
  ```swift
  enum GuardExpression {
      case named(String)          // [isValidURL]
      case negated(String)        // [!isValidURL]  — same closure, inverted
      case `else`                 // [else]
  }
  var guardExpression: GuardExpression?
  ```

* **Parser** (`UrkelParser.swift`) — after parsing `EventDecl`, check for `[`; if next token is `else` consume and produce `.else`; if `!` consume and read identifier for `.negated`; otherwise read identifier for `.named`; require `]`.

* **Semantic validator**:
  - Collect all branches per `(sourceState, eventName)` group.
  - Error if `[else]` is not the last branch in its group.
  - Warning if a guarded group has no `[else]` or `[!guard]` covering the failure case.
  - For `[!guardName]`: verify a matching `[guardName]` or `[else]` exists on the same event (otherwise the negation is the only branch and the positive case is unhandled — warn).
  - Unique guard names (excluding `else`) must each be injected via `Client`.

* **SwiftCodeEmitter**:
  - `[name]` → `if guardName(context) { /* transition */ }`
  - `[!name]` → `if !guardName(context) { /* transition */ }` (reuses same closure property)
  - `[else]` → plain `else { /* transition */ }` at the end of the if-else chain
  - No guard (on an event with no sibling guards) → unconditional, no if-wrapping
  - Chain: multiple guards on the same event → `if … else if … else …` in declaration order

* **Template model** — add `guards: [GuardModel]` (name + isNegated + isElse) to the Mustache model.

## 5. Testing Strategy

* Parser: `[isValid]`; `[!isValid]`; `[else]`; missing closing `]` → error; `[else]` before `[guard]` → parse succeeds, validator catches it.
* Semantic validator: `[else]` not last → error; no failure branch → warning; `[!guard]` with no positive counterpart → warning; missing guard implementation → error.
* Emitter: single guard generates `if`; guard + else generates `if/else`; three branches generate `if/else if/else`; `[!name]` inverts same closure.
* Visualizer: all branch arrows labelled with their guard expression.
* Integration: compile machine with all guard patterns. Add to `generatedSwiftCompiles`.
* Fixture: `GuardedMachine` with all three patterns (A, B, C from DSL syntax above) in `Tests/UrkelTests/Fixtures/`.


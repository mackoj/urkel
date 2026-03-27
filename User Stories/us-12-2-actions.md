# US-12.2: Actions — Entry, Exit, and Transition Side Effects

## 1. Objective

Extend the `.urkel` DSL and compiler to support **named actions**: fire-and-forget side effects that can be attached to state entry, state exit, and individual transitions.

## 2. Context

Urkel currently has no first-class concept of side effects — all side effects live inside the closure implementations injected at construction time. While this works, it makes it impossible to reason statically about *what* happens at a given transition or state boundary, and it blocks visualization and simulation tools from understanding the machine's behaviour.

XState models this as `entry`, `exit`, and per-transition `actions` arrays. Urkel's approach keeps the same semantics but uses a flatter, more readable syntax: actions on transitions are expressed inline with `/ actionName`, and entry/exit actions are declared at the top level of the machine with `@entry`/`@exit` keywords.

Action implementations, like guards, live entirely in Swift and are injected via the `Client` struct. The DSL names them; Swift implements them.

## 3. Acceptance Criteria

* **Given** a transition with an inline action `/ actionName`, **when** the compiler emits Swift, **then** the generated transition method calls the corresponding action closure after the state change.

* **Given** multiple comma-separated actions on a transition `/ logLoad, trackEvent`, **when** Swift is generated, **then** actions are called in declaration order.

* **Given** an `@entry StateName / actionName` declaration, **when** any transition arrives at `StateName`, **then** the generated Swift calls the entry action closure before returning the new machine value.

* **Given** an `@exit StateName / actionName` declaration, **when** any transition departs from `StateName`, **then** the generated Swift calls the exit action closure before the state is consumed.

* **Given** a state with both entry and exit actions, **when** a self-transition occurs on that state, **then** both the exit action (leaving) and entry action (re-entering) fire in order.

* **Given** an `@entry` or `@exit` declaration referencing a state that does not exist in `@states`, **when** the semantic validator runs, **then** it emits a clear diagnostic error.

* **Given** the `Client` struct, **when** actions are present in the machine, **then** each unique action name appears as a `var actionName: @Sendable (ContextType) async -> Void` closure property.

## 4. Implementation Details

* **DSL syntax:**
  ```
  # Transition action (inline, after destination)
  Idle -> load(url: URL) -> Loading / logLoad, trackRequest

  # Entry/exit at top level
  @entry Loading / showSpinner
  @exit  Loading / hideSpinner
  @entry Playing / startAnalytics, beginHeartbeat
  @exit  Playing / stopAnalytics
  ```

* **grammar.ebnf** — add `ActionClause` and `LifecycleDecl` productions:
  ```ebnf
  TransitionStmt  ::= Identifier "->" EventDecl GuardClause? "->" Identifier ForkClause? ActionClause?
  ActionClause    ::= "/" Identifier ("," Identifier)*
  LifecycleDecl   ::= ("@entry" | "@exit") Identifier ActionClause
  ```

* **AST** — add `actions: [String]` to `TransitionNode`; add `EntryActionNode` and `ExitActionNode` (or a single `LifecycleActionNode` with a `kind` discriminator).

* **Parser** — after optional fork clause `=>`, check for `/` and parse comma-separated identifiers. For `@entry`/`@exit`, parse as top-level declarations in the same pass as `@states` and `@transitions`.

* **Semantic validator** — verify all action names referenced in `@entry`/`@exit` correspond to declared states. Warn on declared but unreferenced actions.

* **SwiftCodeEmitter** — collect all unique action names across transitions and lifecycle declarations. Emit each as a `var` closure on `Client`. In transition methods, insert entry/exit calls at the correct point around the state change. Preserve `async` propagation.

* **Template model** — add `entryActions`, `exitActions`, `transitionActions` arrays to Mustache model.

## 5. Testing Strategy

* Parser fixtures: transition with single action, transition with multiple actions, `@entry`/`@exit` declaration, combined guard + action.
* Semantic validator: `@entry` on unknown state → error; duplicate `@entry` for same state → warning (last wins or error, decide policy).
* Emitter: verify entry/exit call order in generated Swift for a self-transitioning state.
* Integration: compile generated Swift for a machine using all action types.
* Add `ActionMachine` fixture in `Tests/UrkelTests/Fixtures/`.

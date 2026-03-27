# US-12.5: Internal Transitions and Wildcard Sources

## 1. Objective

Extend the `.urkel` DSL with two shorthand constructs: **internal transitions** (`-*>`) that handle an event without exiting or re-entering the current state, and **wildcard source** (`*`) transitions that apply from any non-final state, eliminating repetitive boilerplate for cross-cutting events.

## 2. Context

Two patterns recur in almost every real-world state machine:

1. **Progress updates / internal events** — the machine needs to handle an event (e.g., `updateProgress`, `seek`) but should not exit and re-enter its state. In XState these are internal transitions (`{ internal: true }`). Entry/exit actions must NOT fire for these.

2. **Global events** — events like `networkLost`, `sessionExpired`, or `forceStop` should cause a transition from *any* active state. Writing `StateA -> networkLost -> Error`, `StateB -> networkLost -> Error`, etc. for every state is noise that obscures the important transitions. A wildcard `* -> networkLost -> Error` captures this intent clearly.

Both constructs keep the arrow syntax DNA of Urkel while eliminating boilerplate.

## 3. Acceptance Criteria

* **Given** a transition using `-*>` syntax, **when** the event is received, **then** the machine remains in the same state type and neither `@exit` nor `@entry` actions for that state fire.

* **Given** an internal transition with an action (`-*> updateProgress(pct: Double) / emitProgress`), **when** the event fires, **then** the action closure is called but no state change occurs.

* **Given** a wildcard transition `* -> networkLost -> Error`, **when** the machine is in *any* non-final state and `networkLost` fires, **then** it transitions to `Error`.

* **Given** a wildcard transition and a more-specific transition on the same event from a specific state, **when** the specific state receives the event, **then** the specific transition takes precedence over the wildcard.

* **Given** a wildcard transition targeting a `final` state, **when** the semantic validator runs, **then** it emits a warning if the wildcard would match states that already have an explicit transition for that event (shadowing warning, not an error).

* **Given** a `.urkel` file using `*` and `-*>`, **when** code is generated, **then** the wildcard expands to individual transition methods for each matching source state, and internal transitions return `self` (consuming and re-wrapping in the same state type).

## 4. Implementation Details

* **DSL syntax:**
  ```
  # Internal transition — same state, no entry/exit
  Playing -*> seek(position: Double)            / emitProgress
  Playing -*> updateProgress(pct: Double)       / updateUI

  # Wildcard source — from any non-final state
  *       ->  networkLost                       -> Error
  *       ->  sessionExpired                    -> Stopped
  ```

* **grammar.ebnf:**
  ```ebnf
  TransitionArrow  ::= "->" | "-*>"
  TransitionSource ::= Identifier | "*"
  TransitionStmt   ::= TransitionSource TransitionArrow EventDecl GuardClause? (TransitionArrow Identifier ForkClause?)? ActionClause?
  ```
  Note: internal transitions (`-*>`) have no destination; the grammar should make `-> Destination` optional when the arrow is `-*>`.

* **AST** — `TransitionNode` gains `isInternal: Bool` and `sourceIsWildcard: Bool`.

* **Parser** — detect `-*>` token as distinct from `->`. Detect `*` as source identifier.

* **Semantic validator** — internal transition must not have a destination state; wildcard transition must have a destination; warn on shadowed wildcards.

* **SwiftCodeEmitter** — internal transitions generate a `mutating` or `consuming func eventName(...) -> Machine<SameState>` that calls the action and returns `self` re-wrapped. Wildcards expand at emit time to one method per non-final source state, with specific transitions checked first (ordering in the combined enum switch).

## 5. Testing Strategy

* Parser: `-*>` tokenized correctly; `*` source parsed; mix of internal and external in same file.
* Semantic validator: internal transition with destination → error; `*` source with no destination → error; shadowing warning.
* Emitter: internal transition does not change type; wildcard expands to N methods; specific overrides wildcard.
* Integration: compile machine using both constructs.
* Fixture: `WildcardMachine` with a network error wildcard in `Tests/UrkelTests/Fixtures/`.

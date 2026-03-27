# US-12.3: Compound (Nested / Hierarchical) States

## 1. Objective

Extend the `.urkel` DSL and compiler to support **compound states** — states that contain child states — allowing hierarchical state machines (statecharts) where an event can target a parent state and be resolved to a child, and transitions can be defined at the parent level as defaults for all children.

## 2. Context

Urkel currently supports only flat state machines. XState and the original Harel statechart formalism both support hierarchical states, where a parent state groups related child states. This eliminates duplication (e.g., a `stop` event that exits the `Playing` parent regardless of whether it is in `Playing.Buffering` or `Playing.Streaming`) and makes complex machines significantly more readable.

In Urkel v2, compound states are expressed via **indentation** under a parent `state` declaration. The first indented child is the implicit initial child state. There are no braces or nested blocks — the structure reads like a flat list with visual hierarchy.

Dot notation (`Playing.Buffering`) is used to target specific child states in transitions.

## 3. Acceptance Criteria

* **Given** a parent `state Playing` with indented children `state Buffering` and `state Streaming`, **when** the compiler processes the file, **then** it treats `Playing` as a compound state with `Buffering` as the implicit initial child.

* **Given** a transition targeting `Playing` (the parent), **when** the machine enters it, **then** it automatically descends to `Playing.Buffering` (the initial child).

* **Given** a transition targeting `Playing.Streaming` explicitly, **when** the machine enters it, **then** it goes directly to the `Streaming` child without passing through `Buffering`.

* **Given** a transition from `Playing` (parent) to another state, **when** the machine is in any child of `Playing`, **then** the transition matches and exits the compound state.

* **Given** a compound state with `@entry`/`@exit` actions, **when** any child is entered or exited, **then** the parent's entry/exit actions fire at the parent boundary, not at each child transition.

* **Given** a parent state referenced in a transition but no initial child is resolvable, **when** the semantic validator runs, **then** it emits an error.

* **Given** a `.urkel` file with compound states, **when** Swift is generated, **then** child state type markers are nested as inner enums under the parent's namespace (e.g., `Playing.Buffering` as `PlayingBuffering` or `Playing_Buffering`).

## 4. Implementation Details

* **DSL syntax** (indentation-based, no brackets):
  ```
  @states
    init Idle
    state Loading
    state Playing         # compound — first child is initial
      state Buffering
      state Streaming
    state Error
    final Stopped
  ```

* **grammar.ebnf** — `StateDecl` becomes recursive:
  ```ebnf
  StateDecl      ::= StateKind Identifier Newline (Indent StateDecl+ Dedent)?
  StateKind      ::= "init" | "state" | "final"
  ```

* **AST** — `StateNode` gains `children: [StateNode]` and `isCompound: Bool`. The first child is tagged `isInitialChild: Bool`.

* **Parser** — use indentation level tracking (column offset) to determine parent/child relationships. Children must be indented by exactly one level relative to their parent.

* **Semantic validator** — verify compound states have at least one child; verify the initial child is not `final`; verify dot-notation targets in transitions resolve to existing children.

* **SwiftCodeEmitter** — emit child typestate markers with a flattened name (e.g., `PlayingBuffering`). The parent typestate marker becomes an umbrella for type-checking purposes. Transitions targeting the parent resolve to its initial child in generated code.

* **Dot-notation in transitions** — `Playing.Buffering` is parsed as a qualified state reference and resolved during semantic validation.

## 5. Testing Strategy

* Parser: flat machine unchanged; one-level nesting; two-level nesting; mix of flat and nested states in same machine.
* Semantic validator: compound state with no children → error; transition targeting nonexistent child → error; `final` state with children → error.
* Emitter: parent-level transition matches all children; entry/exit fires at parent boundary not inner; dot-notation target generates correct typestate.
* Integration: compile a machine with compound states.
* Fixture: `CompoundMachine` in `Tests/UrkelTests/Fixtures/`.

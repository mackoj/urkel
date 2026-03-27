# US-1.10: Compound States

## Objective

Allow states to contain child states, enabling Hierarchical State Machines (HSMs) where related states are grouped under a common parent, transitions can be defined at the parent level as shared defaults, and the active path through the hierarchy is always unambiguous.

## Background

Flat state machines (US-1.1) become unwieldy when many states share the same behavior. A `stop` event that should exit the current playback state — regardless of whether the player is buffering, streaming, or paused — must be written once per child state. That repetition obscures intent.

Compound states group related children under a parent. A transition targeting the parent descends to its initial child. A transition defined on the parent applies to all children. This is the core of Harel statecharts and the UML statechart formalism.

In Urkel, hierarchy is expressed via **indentation** — children are indented one level beneath their parent `state`. There are no braces or nested blocks. The structure reads like a table with visual depth.

## DSL Syntax

```
machine VideoPlayer: PlayerContext

@states
  init Idle
  state Loading
  state Playing         # compound state — first child is the initial child
    state Buffering
    state Streaming
    state Paused
  state Error
  final Stopped

@transitions
  Idle    -> load(url: URL)  -> Loading
  Loading -> ready           -> Playing    # enters Playing.Buffering (initial child)
  Loading -> failed          -> Error

  # Targets a specific child using dot notation
  Playing.Buffering -> bufferReady -> Playing.Streaming

  # Pausing and resuming within Playing
  Playing.Streaming -> pause       -> Playing.Paused
  Playing.Paused    -> resume      -> Playing.Streaming

  # Defined on the parent — applies to all children of Playing
  Playing -> stop     -> Stopped
  Playing -> error    -> Error

  Error -> retry -> Loading
```

### Deep nesting

```
@states
  state Wizard
    state StepOne
    state StepTwo
      state SubA
      state SubB
    state StepThree
```

### Entry/exit on compound states

```
@entry Playing / startAnalytics    # fires once when Playing is entered from outside
@exit  Playing / stopAnalytics     # fires once when Playing is exited to outside
```

## Acceptance Criteria

* **Given** a parent `state Playing` with indented children, **when** processed, **then** `Playing` is a compound state and the first declared child is its initial child.

* **Given** a transition targeting `Playing` (the parent), **when** taken, **then** the machine automatically descends to the initial child (`Playing.Buffering`).

* **Given** a transition targeting `Playing.Streaming` explicitly, **when** taken, **then** the machine enters directly into `Playing.Streaming` without passing through `Playing.Buffering`.

* **Given** a transition defined on a parent state (`Playing -> stop -> Stopped`), **when** the machine is in **any** child of `Playing`, **then** the parent-level transition is eligible to fire.

* **Given** both a parent-level transition and a child-level transition for the same event, **when** the machine is in the specific child, **then** the child-level transition takes **precedence** over the parent-level one.

* **Given** `@entry Playing / action`, **when** any transition arrives at `Playing` (regardless of which child is entered), **then** the entry action fires **once** at the parent boundary — not once per child transition.

* **Given** a compound state with no children, **when** validated, **then** an error is emitted: `"Compound state 'X' must have at least one child state"`.

* **Given** a `final` state with indented children, **when** validated, **then** an error is emitted: `"Final states cannot be compound"`.

* **Given** a dot-notation target `Playing.Buffering` where `Buffering` is not a child of `Playing`, **when** validated, **then** an error is emitted: `"State 'Buffering' is not a child of 'Playing'"`.

* **Given** an `init` state with indented children (compound init state), **when** validated, **then** it is valid — the initial state of the machine can itself be a compound state.

## Grammar

```ebnf
StateStmt     ::= StateKind Identifier Newline (Indent StateStmt+ Dedent)?
QualifiedIdent ::= Identifier ("." Identifier)*    # used in TransitionStmt for dot notation
```

Children are detected by an increase in indentation level relative to their parent `state` line. One consistent indentation increment per level is required (the DSL does not mandate spaces vs. tabs, but must be consistent within a file).

## Notes

- Dot notation (`Parent.Child`) is only valid in `@transitions`. In `@states`, hierarchy is expressed purely by indentation.
- The depth of nesting is not formally limited by the grammar, but deep nesting (more than 2–3 levels) is discouraged for readability.
- History states (US-1.11) build on compound states to enable re-entry at the last-visited child.
- Parallel regions (US-1.12) are a separate orthogonal concept — they are not expressed as compound state children.

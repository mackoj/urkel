# US-1.1: Core Machine Structure

## Objective

Define the minimal valid `.urkel` file — the three required building blocks every machine must declare: the machine header, the state space, and the transition table.

## Background

A `.urkel` file is the complete, authoritative description of a single state machine. Three declarations are always required:

1. **`machine`** — names the machine and optionally binds a context type.
2. **`@states`** — enumerates every state the machine can be in.
3. **`@transitions`** — enumerates every legal movement between states.

A file with all three forms a minimal flat FSM. Everything else in the DSL (guards, actions, hierarchy, …) is layered on top of this foundation.

## DSL Syntax

```
machine TrafficLight

@states
  init Red
  state Green
  state Yellow
  final Off

@transitions
  Red    -> timer -> Green
  Green  -> timer -> Yellow
  Yellow -> timer -> Red
  Red    -> powerOff -> Off
```

### With a context type

```
machine Thermostat: ThermostatContext

@states
  init Idle
  state Heating
  state Cooling
  final Shutdown

@transitions
  Idle    -> startHeating -> Heating
  Idle    -> startCooling -> Cooling
  Heating -> targetReached -> Idle
  Cooling -> targetReached -> Idle
  Idle    -> shutdown -> Shutdown
```

## Acceptance Criteria

* **Given** a `.urkel` file with a `machine` header, a `@states` block, and a `@transitions` block, **when** the file is processed, **then** it is accepted as valid.

* **Given** a `@states` block, **when** processed, **then** it must contain exactly one `init` state, zero or more `state` declarations, and at least one `final` state; any other combination is an error.

* **Given** a `machine` header without a context type (`machine Foo`), **when** processed, **then** the machine is declared without a bound context — valid and complete.

* **Given** a `machine` header with a context type (`machine Foo: FooContext`), **when** processed, **then** `FooContext` is treated as an opaque type name supplied by the host language; the DSL does not define it.

* **Given** a state name referenced in `@transitions` that does not appear in `@states`, **when** validated, **then** an error is emitted: `"Unknown state 'X'"`.

* **Given** a state declared in `@states` that is never the source or destination of any transition, **when** validated, **then** a warning is emitted: `"State 'X' is unreachable"` (except for `init` and `final` states with no outgoing/incoming transitions respectively, which are structural).

* **Given** a `@transitions` block containing two transitions with the same `(source, event)` pair and no guard on either, **when** validated, **then** an error is emitted: `"Duplicate transition: 'State -> event'"`.

* **Given** an `init` state that has no outgoing transitions, **when** validated, **then** an error is emitted (a machine that can never leave its initial state is a deadlock).

* **Given** a `final` state, **when** validated, **then** it must have no outgoing transitions (final states are terminal — they cannot transition anywhere).

* **Given** a `.urkel` file missing any of the three required blocks, **when** processed, **then** an error identifies the missing block.

## Grammar

```ebnf
UrkelFile    ::= MachineDecl StatesBlock TransitionsBlock
MachineDecl  ::= "machine" Identifier ContextDecl? Newline
ContextDecl  ::= ":" Identifier
StatesBlock  ::= "@states" Newline StateStmt+
StateStmt    ::= StateKind Identifier Newline
StateKind    ::= "init" | "state" | "final"
TransBlock   ::= "@transitions" Newline TransitionStmt+
TransitionStmt ::= Identifier "->" Identifier "->" Identifier Newline
```

## Notes

- State names and event names are `PascalCase` and `camelCase` respectively by convention, but the DSL enforces only that they are valid identifiers.
- The context type (`: ContextType`) is a single identifier. Generic or compound Swift types (e.g., `[String: Any]`) are not valid here — use a named type alias in the host language.
- Declaration order in `@states` and `@transitions` is significant for readability but has no semantic effect, except where stated otherwise in later stories (e.g., guard evaluation order in US-1.6).

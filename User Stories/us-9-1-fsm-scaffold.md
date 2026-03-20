# US-9.1: Generic FSM Scaffold

## 1. Objective
Generate the reusable typed state-machine scaffold so Urkel users do not need to hand-write the same observer, state, and transition wrappers for every machine.

## 2. Context
FolderWatch shows that a lot of FSM code is not domain logic at all. The repeated `Machine`, `Observer<State>`, `State`, and transition plumbing is generic enough to belong in Urkel, leaving each package to describe only its own states and transitions.

## 3. Acceptance Criteria
* **Given** a machine definition with an initial state and one or more transitions.
* **When** Urkel emits Swift.
* **Then** it generates a typed observer wrapper for each state.
* **And Then** transition methods are `consuming` so the compiler prevents state reuse.

* **Given** a transition `Idle -> start -> Running`.
* **When** emitted.
* **Then** the generated API exposes `public consuming func start() async throws -> MachineObserver<Running>`.

* **Given** multiple transitions from the same state.
* **When** emitted.
* **Then** Urkel groups them under a single `extension ... where State == ...` block.

## 4. Implementation Details
* Teach the emitter to generate the machine namespace, the observer wrapper, and the typed state markers as a reusable template.
* Keep the transition implementation hooks generic so the package can inject domain-specific runtime behavior later.
* Ensure the generated code keeps compile-time state safety without adding reflection or runtime casts.

## 5. Testing Strategy
* Add emitter tests for a small machine with one start transition and one stop transition.
* Add a compile test that confirms invalid transitions fail to build.

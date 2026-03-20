# US-9.2: Lifecycle Context Storage

## 1. Objective
Provide reusable lifecycle context storage so Urkel-generated machines can carry state-specific runtime data without each package rebuilding the same private context container.

## 2. Context
FolderWatch uses a context type to move data between idle, running, and stopped states. The shape is generic even if the payload is domain-specific, which makes it a strong candidate for Urkel support.

## 3. Acceptance Criteria
* **Given** a machine with state-specific runtime payloads.
* **When** Urkel emits Swift.
* **Then** the generated code provides a safe container for those payloads across state transitions.

* **Given** a transition that needs to read the current state’s context.
* **When** the generated code runs.
* **Then** the transition handler receives typed state data rather than `Any`.

* **Given** multiple machines in the same module.
* **When** they are generated.
* **Then** their context storage helpers do not collide at the symbol level.

## 4. Implementation Details
* Generate a machine-scoped context wrapper and state storage helpers as part of the emitted runtime scaffolding.
* Keep the concrete payload types supplied by the package author rather than baked into Urkel.
* Preserve a narrow internal API so sidecar runtime code can transition between states without exposing implementation details publicly.

## 5. Testing Strategy
* Add a snapshot test for the generated context wrapper.
* Add a multi-machine compile test that proves the helpers remain namespaced.

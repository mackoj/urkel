# US-11.2: The Orchestrator Actor Emitter

## 1. Objective
When an Urkel file uses `@compose`, generate an overarching Swift `actor` (The Orchestrator) that safely encapsulates and manages the lifecycles of both the parent `~Copyable` state machine and its composed parallel machines.

## 2. Context
Because Typestate tokens are `~Copyable` (noncopyable) and `~Escapable`, they cannot be easily shared across concurrent boundaries. To make parallel composition ergonomic, the Emitter must generate an Actor. This Actor holds the mutable state of the parent machine and optional properties for any composed machines, providing a safe, thread-isolated API for the implementor to route events between them.

## 3. Acceptance Criteria
* **Given** an AST with no `@compose` declarations.
* **When** emitted.
* **Then** it generates the standard `[MachineName]Client` and wrappers as defined in Epic 4. (No Orchestrator needed).
* **Given** an AST for `Scale` that composes `BLE`.
* **When** emitted.
* **Then** the emitter generates `public actor ScaleOrchestrator`.
* **And Then** the Orchestrator contains private state variables: `private var scaleState: ScaleState` and `private var bleState: BLEState?`.
* **Given** a transition with a Fork operator (`=> BLE.init`).
* **When** the generated Swift transition method is called inside the Orchestrator.
* **Then** the method updates `self.scaleState` to the new state AND initializes `self.bleState` with a fresh `BLEObserver`.

## 4. Implementation Details
* In `UrkelEmitter`, add a check: `if !ast.composedMachines.isEmpty`, trigger the Orchestrator generation phase.
* **Actor Generation:** Output `public actor [MachineName]Orchestrator`.
* **State Management:** Define variables for the parent machine (non-optional, initialized in the Actor's `init`) and composed machines (optional, initialized to `nil`).
* **Event Routing API:** Generate public async methods on the Actor corresponding to the events. The implementation will `switch` on the internal `ScaleState`. If valid, it executes the consuming transition and stores the new state token. If a `=>` fork was specified in the AST, it assigns a new instance to the composed machine's variable.

## 5. Testing Strategy
* **Integration Tests:** Generate the Orchestrator Swift code for the `Scale`/`BLE` example. Write a test file that instantiates the `ScaleOrchestrator`, calls the `hardwareReady` event, and asserts that the internal BLE state successfully transitioned from `nil` to its `init` state.

# US-4.2: Swift Emitter - State Transitions

## 1. Objective
Generate the state-constrained Swift extensions containing the `consuming` methods that dictate the Typestate transitions.

## 2. Context
This is the heart of the Typestate pattern. We must generate code that proves to the Swift compiler that a specific event can only occur in a specific state. The generated methods must consume the current `Observer` (destroying it to prevent state reuse) and return a newly instantiated `Observer` locked into the target state.

## 3. Acceptance Criteria
* **Given** a transition `Idle -> start -> Running` in the AST.
* **When** emitted.
* **Then** the generator outputs an `extension [MachineName]Observer where State == Idle`.
* **And Then** inside that extension, it outputs: `public consuming func start() async throws -> [MachineName]Observer<Running>`.
* **Given** a transition with a payload `Scanning -> found(device: Peripheral) -> Connecting`.
* **When** emitted.
* **Then** the generated function signature includes the parameter: `public consuming func found(device: Peripheral) async throws -> [MachineName]Observer<Connecting>`.
* **Given** multiple outbound transitions from the same state (e.g., `Idle -> start -> Running`, `Idle -> fail -> Error`).
* **When** emitted.
* **Then** both functions are grouped inside a single `extension [MachineName]Observer where State == Idle` block.

## 4. Implementation Details
* In `UrkelEmitter.swift`, create a helper `emitExtensions(for ast: MachineAST) -> String`.
* Group the transitions by their `from` state: `Dictionary(grouping: ast.transitions, by: { $0.from })`.
* Iterate over the dictionary. For each key (state), open an `extension MachineObserver where State == \(key) {`.
* Iterate over the transitions for that state.
* Format parameters if they exist: `let paramString = transition.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")`.
* Generate the method body: It must `try await` the corresponding injected closure (e.g., `_start(internalContext)`), and then return the new `Observer<NextState>` passing down the `internalContext` and all closures.

## 5. Testing Strategy
* **Unit Tests:** Pass an AST with grouped transitions and payloads into the emitter. Use `XCTAssertTrue` to ensure the resulting string contains the exact `extension` signature, the `consuming` keyword, the parameter injection, and the return type.
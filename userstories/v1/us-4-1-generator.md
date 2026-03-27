# US-4.1: Implement the Typestate Swift Emitter

## 1. Objective
Build the code generation engine (`UrkelEmitter`) that translates a validated `MachineAST` into a string of production-ready Swift code utilizing the Typestate pattern.

## 2. Context
This is the core value proposition of Urkel. The Emitter takes the abstract concepts (states, transitions, payloads) and maps them exactly to the `FolderWatchObserver` architectural pattern. It must generate the state enums, the `~Copyable` observer struct, the state-constrained extensions, and the `swift-dependencies` client.

## 3. Acceptance Criteria
* **Given** a valid AST with `@imports import Foundation`.
* **When** `UrkelEmitter.emit(ast:)` is called.
* **Then** the output string begins with `import Foundation` and the required boilerplate.
* **Given** an AST with `@states init Idle`.
* **When** emitted.
* **Then** the output contains `public enum Idle {}`.
* **Given** an AST with `@transitions Idle -> start -> Running`.
* **When** emitted.
* **Then** the output contains `extension FolderWatchObserver where State == Idle` with a `consuming func start() async -> FolderWatchObserver<Running>` that calls `_start(internalState)`.
* **Given** an AST with `@factory makeObserver(url: URL)`.
* **When** emitted.
* **Then** the output contains a Dependency Client struct with the correct `makeObserver` signature.

## 4. Implementation Details
* Create `public struct UrkelEmitter`.
* For V1, use multi-line Swift string interpolation (`"""`) to build the file top-to-bottom.
* **Phase 1:** Emit file header and `@imports`.
* **Phase 2:** Emit Marker Types (Enums).
* **Phase 3:** Emit the main `Observer<State>: ~Copyable` struct. Iterate through all unique transitions to generate the `let _eventName: @Sendable ...` closure properties.
* **Phase 4:** Emit `extension Observer where State == [State]` blocks. Group transitions by their `from` state to populate the correct extensions.
* **Phase 5:** Emit the `Client` struct and `DependencyValues` extension.

## 5. Testing Strategy
* Create `UrkelEmitterTests`.
* Pass a known, valid `MachineAST` (like FolderWatch) into the emitter.
* Assert that the resulting `String` contains specific substrings (e.g., `XCTAssertTrue(output.contains("public enum Idle {}"))`).
* *(Integration)* Write the output string to a temporary `.swift` file and run `swift build` on it in a test process to ensure the generated code actually compiles.
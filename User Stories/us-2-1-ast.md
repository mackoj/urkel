# US-2.1: Define the Abstract Syntax Tree (AST)

## 1. Objective
Create the Swift data structures (`MachineAST` and its sub-types) that will represent the parsed state of an `.urkel` file in memory.

## 2. Context
The compiler pipeline requires a bridge between raw text and semantic analysis. We cannot validate or emit code directly from a string. The AST serves as the single source of truth for the entire pipeline. It must perfectly model the Urkel dialect (Imports, Machine Name, Context Type, Factory, States, and Transitions) and strictly conform to `Equatable` to make unit testing the Parser painless.

## 3. Acceptance Criteria
* **Given** the need to represent a full Urkel file.
* **When** a developer instantiates a `MachineAST`.
* **Then** it contains properties for `imports` ([String]), `machineName` (String), `contextType` (String?), `factory` (Factory?), `states` ([StateNode]), and `transitions` ([TransitionNode]).
* **Given** the need to represent an event payload (e.g., `device: Peripheral`).
* **When** a `Parameter` struct is created.
* **Then** it holds a `name` and a `type` (both Strings).
* **Given** the need to categorize states.
* **When** a `StateNode` is created.
* **Then** it utilizes an enum `Kind` to distinguish between `.initial`, `.normal`, and `.terminal`.
* **Given** two identical `MachineAST` instances constructed independently.
* **When** compared using `==`.
* **Then** the result is `true`.

## 4. Implementation Details
* Create a new file: `Sources/Urkel/MachineAST.swift`.
* Define `public struct MachineAST: Equatable`.
* Nest the sub-types within `MachineAST` to namespace them cleanly (e.g., `MachineAST.StateNode`).
* Define `public struct Factory: Equatable { let name: String; let parameters: [Parameter] }`.
* Define `public struct Parameter: Equatable { let name: String; let type: String }`.
* Define `public struct StateNode: Equatable { let name: String; let kind: Kind }` with `public enum Kind: Equatable { case initial, normal, terminal }`.
* Define `public struct TransitionNode: Equatable { let from: String; let event: String; let parameters: [Parameter]; let to: String }`.

## 5. Testing Strategy
* **Unit Tests:** Create `MachineASTTests.swift`.
* Write a test that manually constructs a complete `MachineAST` representing the `FolderWatch` machine.
* Verify that all types initialize correctly and that equality checks behave as expected (especially for the nested arrays). This guarantees that when the Parser is built, we can write asserts like `XCTAssertEqual(parsedAST, expectedAST)`.
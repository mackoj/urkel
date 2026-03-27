# US-11.1: The Fork Operator & Composition AST

## 1. Objective
Introduce the `@compose` keyword and the `=>` (Fork) operator to the Urkel EBNF grammar, allowing a parent machine to declare and instantiate parallel sub-machines without merging their state spaces.

## 2. Context
To support complex IoT workflows (like a Scale running a BLE sequence), Urkel must support composition. Instead of brittle inheritance or messy namespace merging, Urkel uses parallel execution. The parent machine transitions to its next state and simultaneously "forks" a composed machine, starting it at its `init` state.

## 3. Acceptance Criteria
* **Given** a valid `.urkel` file.
* **When** it includes `@compose BLE`.
* **Then** the parser successfully adds `BLE` to a `composedMachines: [String]` array on the `MachineAST`.
* **Given** a transition utilizing the Fork operator: `WakingUp -> hardwareReady -> Tare => BLE.init`.
* **When** parsed.
* **Then** the `TransitionNode` successfully captures `BLE` as the spawned parallel machine.
* **Given** a transition that tries to fork a machine NOT listed in `@compose`.
* **When** validated by `UrkelValidator`.
* **Then** it throws an `unresolvedComposedMachine` error.

## 4. Implementation Details
* **Grammar Updates:** * Add `ComposeDecl ::= "@compose" Whitespace Identifier Newline`.
  * Update `TransitionStmt` to optionally end with `"=>" Whitespace? Identifier ".init"`.
* **AST Updates:** Add `let spawnedMachine: String?` to `TransitionNode`. Add `let composedMachines: [String]` to `MachineAST`.
* **Validator Updates:** Ensure that any string captured by `spawnedMachine` matches an identifier defined in the `@compose` block.

## 5. Testing Strategy
* **Parser Unit Tests:** Parse the fork syntax and assert the AST `TransitionNode.spawnedMachine` equals `"BLE"`.

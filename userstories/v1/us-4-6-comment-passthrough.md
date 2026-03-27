# US-4.6: Doc Comment Pass-Through

## 1. Objective
Update the Parser and Emitter pipelines to capture `#` comments in the `.urkel` file and emit them as `///` Swift documentation comments above the generated types and functions.

## 2. Context
As Urkel machines become more complex, the `.urkel` file acts as the primary architectural documentation. However, developers implementing the business logic in Swift need to see that context directly in their IDE. By converting DSL comments into Swift doc comments, Xcode's Quick Help and autocomplete will natively display the architectural intent (e.g., "FORK: Move Scale to Tare...").

## 3. Acceptance Criteria
* **Given** a transition preceded by a comment:
  ```text
  # Starts the BLE radio
  Idle -> start -> Scanning
  ```
* **When** parsed and emitted.
* **Then** the generated Swift code includes the comment as standard documentation:
  ```swift
  /// Starts the BLE radio
  public consuming func start() async -> Observer<Scanning>
  ```
* **Given** a multi-line comment above a state or transition.
* **When** parsed and emitted.
* **Then** all lines are preserved and prefixed with `///`.

## 4. Implementation Details
* **Parser Update:** Modify the `swift-parsing` EBNF rules. Instead of purely ignoring comments as whitespace, optionally capture preceding comments and attach them as a `[String]` to the `TransitionNode` and `StateNode` AST structures.
* **Emitter Update:** In `UrkelEmitter`, before outputting a `public enum` or `public consuming func`, iterate over the node's comments array and output `/// \(commentLine)`.

## 5. Testing Strategy
* **Unit Tests:** Pass an AST node containing `["Test comment"]` into the emitter. Assert that the resulting string contains `/// Test comment\n public consuming func...`.

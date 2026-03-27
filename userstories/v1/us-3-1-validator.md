# US-3.1: Implement the Semantic Validator (With BYOT Support)

## 1. Objective
Build a static analysis pass (`UrkelValidator`) that inspects the parsed `MachineAST` for logical domain errors before any Swift code is generated, while strictly respecting the Bring-Your-Own-Types (BYOT) boundary.

## 2. Context
The parser guarantees the syntax matches the EBNF, but it does not guarantee the logic is mathematically sound. If a developer writes a transition pointing to a misspelled state (e.g., `Idle -> start -> Runing`), generating Swift code will result in confusing generic compiler errors. We must catch these graph errors at the AST level. However, because of the BYOT rule, the validator must *trust* the developer's payload types and not attempt to resolve them.

## 3. Acceptance Criteria
* **Given** an AST with no `init` state defined in the `@states` block.
* **When** `UrkelValidator.validate(ast:)` is called.
* **Then** it throws `.missingInitialState`.
* **Given** an AST where a transition's `to` or `from` state is not listed in `@states`.
* **When** validated.
* **Then** it throws `.unresolvedStateReference(stateName: "Runing")`.
* **Given** an AST with a complex Swift type parameter: `deviceFound(device: Result<CBPeripheral, CoreBluetoothError>)`.
* **When** validated.
* **Then** the validator explicitly ignores type resolution for the parameter, validates the state references successfully, and returns the AST unmodified.

## 4. Implementation Details
* Create `public struct UrkelValidator`.
* Implement a single `public static func validate(_ ast: MachineAST) throws` method.
* **Pass 1 (Init Check):** Filter `ast.states` for `.kind == .initial`. Assert `count == 1`.
* **Pass 2 (State Resolution):** Extract all state names into a `Set<String>`. Iterate through `ast.transitions`. Assert that `transition.from` and `transition.to` exist in the set.
* Ensure there is no code attempting to validate the contents of the `Parameter.type` strings.

## 5. Testing Strategy
* **Unit Tests:** Create `UrkelValidatorTests`.
* Programmatically construct invalid `MachineAST` objects (bypassing the parser) and assert that `validate()` throws the correct, highly specific error cases.
* Construct a valid AST that contains wild, intentionally broken Swift types in the payloads (e.g., `param: !@#NotRealSwift`). Assert that `validate()` passes successfully, proving the BYOT boundary holds firm.
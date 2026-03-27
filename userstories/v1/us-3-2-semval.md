# US-3.2: Semantic Validator - Initial State Integrity

## 1. Objective
Enhance the `UrkelValidator` to ensure that every parsed `MachineAST` defines exactly one initial state.

## 2. Context
A finite state machine is mathematically invalid without a starting point. In the context of our Swift generator, the `@factory` method needs to know exactly which `State` marker to wrap the `Observer` in upon creation. If there are zero `init` states, the machine can't start. If there are multiple, the factory becomes ambiguous.

## 3. Acceptance Criteria
* **Given** a `MachineAST` where `states` contains zero nodes with `kind == .initial`.
* **When** `UrkelValidator.validate(ast:)` is called.
* **Then** it throws a `UrkelValidationError.missingInitialState` error.
* **Given** a `MachineAST` where `states` contains two or more nodes with `kind == .initial`.
* **When** `UrkelValidator.validate(ast:)` is called.
* **Then** it throws a `UrkelValidationError.multipleInitialStates` error.
* **Given** a `MachineAST` where `states` contains exactly one `.initial` node.
* **When** validated.
* **Then** it passes this validation check and proceeds.

## 4. Implementation Details
* In `UrkelValidator.swift`, add a private throwing method `checkInitialState(in ast: MachineAST)`.
* Filter the `ast.states` array: `let initStates = ast.states.filter { $0.kind == .initial }`.
* Switch on `initStates.count`:
  * `case 0`: throw missing error.
  * `case 1`: return successfully.
  * `default`: throw multiple error.

## 5. Testing Strategy
* **Unit Tests:** Inside `UrkelValidatorTests`, manually construct three `MachineAST` objects: one with no init, one with two inits, and one with exactly one init. Use `XCTAssertThrowsError` to verify the correct custom errors are triggered for the invalid ASTs.
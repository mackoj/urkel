# US-10.1: Zero-Argument Factory Closure Emission

## 1. Objective
Ensure generated Swift is valid when a machine factory has no parameters (for example `@factory makeGame()`), by emitting correct closure syntax in runtime builder scaffolding.

## 2. Context
Current emission can produce `makeX: { in ... }` for zero-argument factories, which is invalid Swift syntax. This blocks otherwise-valid machines and confuses users when a basic example fails to compile.

## 3. Acceptance Criteria
* **Given** a machine with `@factory makeGame()`.
* **When** Swift is emitted.
* **Then** runtime builder code emits `makeGame: { ... }` (without `in`).

* **Given** a machine with factory parameters, like `@factory makeObserver(url: URL)`.
* **When** Swift is emitted.
* **Then** runtime builder code still emits parameter names followed by `in` (for example `{ url in ... }`).

## 4. Implementation Details
* Update `SwiftCodeEmitter.emitClientRuntimeBuilder` to special-case zero-argument factory closure signatures.
* Keep generated shape and API surface unchanged except for closure syntax correctness.
* Add regression tests in emitter tests for both zero-arg and parameterized factories.

## 5. Testing Strategy
* Add/extend inline snapshot tests validating emitted runtime builder code.
* Compile fixture tests should include one zero-arg machine.

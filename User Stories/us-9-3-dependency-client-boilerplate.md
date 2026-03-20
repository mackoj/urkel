# US-9.3: Dependency Client Boilerplate

## 1. Objective
Generate the standard `Dependencies` client layer for each FSM so packages do not have to rewrite the same `DependencyKey`, `DependencyValues`, and factory plumbing.

## 2. Context
FolderWatch’s client layer follows a pattern that is likely to repeat in many Urkel-backed packages: a factory for creating the observer plus live/test/preview defaults. That wiring is generic and should be generated consistently.

## 3. Acceptance Criteria
* **Given** a machine definition.
* **When** Urkel emits client code.
* **Then** it generates a client type with a factory for creating the observer.

* **Given** the generated client is integrated with `Dependencies`.
* **When** a package reads the dependency.
* **Then** it can construct an observer through a stable API.

* **Given** test and preview environments.
* **When** the dependency is not configured.
* **Then** Urkel provides predictable defaults or clearly marked unimplemented values.

## 4. Implementation Details
* Emit a small client type plus `DependencyKey` and `DependencyValues` integration.
* Keep the generated API stable across machines so consumers learn one integration pattern.
* Allow the package to provide custom live/test behavior without editing generated files.

## 5. Testing Strategy
* Add a generated-client compile test with `Dependencies`.
* Add a test that verifies the dependency value can be overridden in a test environment.

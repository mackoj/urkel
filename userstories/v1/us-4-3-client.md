# US-4.3: Swift Emitter - Dependency Client

## 1. Objective
Generate the outer wrapper Client struct and the Point-Free `swift-dependencies` boilerplate to allow easy dependency injection of the state machine into the host app.

## 2. Context
To make the generated machine ergonomic and testable in a modern Swift architecture, it shouldn't just exist as floating types. It needs a factory client (like `FolderWatchClient`) that acts as the entry point. The developer will extend this client in their own code to provide the `liveValue` and `testValue`.

## 3. Acceptance Criteria
* **Given** a machine named `Bluetooth` and an AST with `@factory makeObserver(url: URL)`.
* **When** emitted.
* **Then** it generates `public struct BluetoothClient: Sendable`.
* **And Then** it generates a property: `public var makeObserver: @Sendable (URL) -> BluetoothObserver<Disconnected>` (assuming `Disconnected` is the `init` state).
* **And Then** it generates the struct's initializer mapping the factory method.
* **Given** the requirement for Point-Free dependencies.
* **When** emitted.
* **Then** it generates an empty `extension BluetoothClient: TestDependencyKey` (leaving `liveValue` up to the developer).
* **And Then** it generates an `extension DependencyValues` exposing `public var bluetooth: BluetoothClient`.

## 4. Implementation Details
* In `UrkelEmitter.swift`, create a helper `emitClient(for ast: MachineAST) -> String`.
* Locate the `.initial` state from the AST to know what the factory returns.
* Format the `@factory` parameters for both the property signature and the initializer signature.
* Generate the `struct [Name]Client`.
* Generate the `DependencyValues` extension. Standardize the dependency key by lowercasing the first letter of the machine name (e.g., `Bluetooth` becomes `var bluetooth: BluetoothClient`).

## 5. Testing Strategy
* **Unit Tests:** Pass a populated AST with a factory definition into the emitter. Assert the presence of the `DependencyValues` extension, the `TestDependencyKey` conformance, and the correct `makeObserver` signature in the output string.
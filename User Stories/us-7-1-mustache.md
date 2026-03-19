# US-7.1: Build the Pluggable Mustache Export Engine

## 1. Objective
Introduce `swift-mustache` as an optional, secondary export pipeline for the AST, allowing Urkel to generate code for foreign languages without altering the native Swift `UrkelEmitter`.

## 2. Context
The core Urkel compiler generates Swift code natively directly from the AST to ensure maximum performance and safety. However, domain logic defined in `.urkel` files often needs to be shared across platforms (e.g., an Android app or a web frontend). Instead of writing native emitters for every language on earth, we will build a `MustacheExportEngine`. This engine will convert the strongly-typed `MachineAST` into a generic dictionary payload and feed it into user-provided `.mustache` templates.

## 3. Acceptance Criteria
* **Given** the Urkel package dependencies.
* **When** resolving packages.
* **Then** `hummingbird-project/swift-mustache` is successfully fetched.
* **Given** a parsed and validated `MachineAST`.
* **When** passed to the new `MustacheExportEngine`.
* **Then** the engine successfully maps the AST into a `[String: Any]` context dictionary (e.g., mapping `states` to an array of dictionaries).
* **Given** a mock `test.mustache` template containing `Hello {{machineName}}`.
* **When** the engine renders the template with a Machine named `FolderWatch`.
* **Then** it outputs the string `Hello FolderWatch`.

## 4. Implementation Details
* Add `swift-mustache` to `Package.swift`.
* Create `MustacheExportEngine.swift`.
* Create a `MachineAST+Dictionary.swift` extension that translates the AST into a JSON-like structure compatible with Mustache rendering.
* The engine should have a simple API: `func render(ast: MachineAST, templateString: String) throws -> String`.
* Ensure this engine is structurally completely separate from the `UrkelEmitter` (which handles native Swift).

## 5. Testing Strategy
* **Unit Tests:** Create `MustacheExportEngineTests`. Define a hardcoded `MachineAST` and a simple `.mustache` string. Assert that `engine.render()` successfully injects the AST data into the template.

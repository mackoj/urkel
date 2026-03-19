# US-7.2: CLI Support for Bring-Your-Own-Language (BYOL)

## 1. Objective
Update the `urkel generate` command to accept custom template files. If a template is provided, bypass the native Swift emitter and route the AST to the Mustache Export Engine instead.

## 2. Context
To make Urkel a universal state machine tool, developers need a way to pass their own language templates via the command line. The default behavior remains Swift, but a new flag will unlock the Mustache pipeline.

## 3. Acceptance Criteria
* **Given** the `urkel generate` command.
* **When** the user runs `urkel --help`.
* **Then** a new optional argument `--template <path>` is documented.
* **Given** a developer runs `urkel generate ./Bluetooth.urkel --output ./out`.
* **When** the command executes.
* **Then** it uses the native `UrkelEmitter` and outputs `Bluetooth+Generated.swift`.
* **Given** a developer runs `urkel generate ./Bluetooth.urkel --template ./custom.ts.mustache --output ./out`.
* **When** the command executes.
* **Then** it detects the template flag, bypasses the Swift emitter, passes the AST and the template file to the `MustacheExportEngine`, and outputs a file based on the template (e.g., `Bluetooth.ts`).

## 4. Implementation Details
* In `Urkel.swift` (the CLI parser), add `@Option(name: .shortAndLong, help: "Path to a custom .mustache template for foreign language generation") var template: String?`.
* In `UrkelGenerator.generate(file:)`:
  * Parse and Validate the AST as usual.
  * `if let templatePath = template` -> Read the template file, call `MustacheExportEngine.render`, and write the output.
  * `else` -> Call `UrkelEmitter.emit` (the native Swift route) and write the output.
* Add an `--ext` (extension) option to the CLI so the user can specify if the output file should be `.ts`, `.kt`, `.cpp`, etc., when using a custom template.

## 5. Testing Strategy
* **Integration Tests:** Create a mock `python.mustache` file. Run the CLI command pointing to it with `--ext py`, and assert that the CLI successfully routes the data through the Mustache engine and outputs a `.py` file.

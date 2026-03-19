# US-7.3: Bundle Official Foreign Templates (Kotlin)

## 1. Objective
Bundle highly opinionated, officially supported Mustache templates (starting with Kotlin) within the Urkel SPM package, accessible via a simple language flag.

## 2. Context
While developers can write their own templates, providing an official Kotlin template out-of-the-box makes Urkel immediately valuable for mobile teams building for both iOS and Android.

## 3. Acceptance Criteria
* **Given** the CLI is running.
* **When** the user runs `urkel --help`.
* **Then** a new optional argument `--lang <language>` is documented (e.g., `--lang kotlin`).
* **Given** a user runs `urkel generate ./Machine.urkel --lang kotlin`.
* **When** the command executes.
* **Then** the CLI loads the bundled `kotlin.mustache` file from the package resources and routes it through the Mustache engine.
* **Given** the official `kotlin.mustache` file.
* **When** it renders a valid AST.
* **Then** the output is a mathematically sound Kotlin representation of the Typestate pattern using `sealed interface` and `class` hierarchies.

## 4. Implementation Details
* Add a `Templates/` directory to the Swift Package and declare it as a `.process("Templates")` resource in `Package.swift`.
* Write `kotlin.mustache` focusing on exhaustive `when` statements and sealed classes to mimic Swift's compile-time safety as closely as possible in Kotlin.
* Update the CLI to accept `--lang`. Map the string `"kotlin"` to the bundled resource path.

## 5. Testing Strategy
* **Snapshot Tests:** Pass a known `MachineAST` into the bundled Kotlin template. Verify the generated string exactly matches a handwritten, perfectly formatted Kotlin file representing the target state machine.

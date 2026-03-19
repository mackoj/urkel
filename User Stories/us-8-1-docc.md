# US-8.1: Establish Swift-DocC Foundation & Core Reference

## 1. Objective
Integrate Swift-DocC into the Urkel package and generate the foundational API reference for the compiler, the CLI commands, and the expected generated runtime code (like the `Client` and `State` wrapper).

## 2. Context
Before writing conceptual articles, we need a working DocC catalog. This establishes the baseline where all public Swift types in the Urkel compiler (like `MachineAST`, `UrkelParser`, and `UrkelValidator`) are documented via inline `///` comments. It also requires documenting the CLI arguments (`generate`, `watch`, `--template`) so users know how to run the tool.

## 3. Acceptance Criteria
* **Given** the Urkel package.
* **When** a developer runs `swift package generate-documentation`.
* **Then** the DocC compiler successfully builds a `.doccarchive` without warnings.
* **Given** the DocC output.
* **When** navigating the index.
* **Then** all public API surfaces (CLI commands, AST nodes, Parser errors) have clear descriptions and parameter explanations.
* **Given** the documentation catalog.
* **When** viewing the "Generated Output" section.
* **Then** there is a dedicated page detailing the structure of the generated Swift code (the `~Copyable` wrapper, dependency client, and state-unwrapping accessors).

## 4. Implementation Details
* Add a `Urkel.docc` catalog folder to the package.
* Write inline markdown comments (`///`) for all `public` entities in the codebase.
* Create a root `Urkel.md` landing page inside the `.docc` folder that provides a high-level overview (reusing the concepts from our README).
* Create an article named `Generated-Runtime-API.md` explaining how to interact with the code Urkel emits.

## 5. Testing Strategy
* Run `swift run docc preview` locally and manually verify that the site navigation is logical, links are not broken, and the landing page renders correctly.

# US-5.2: SPM Build Tool Plugin

## 1. Objective
Create an SPM `BuildToolPlugin` that automatically invokes the Urkel CLI executable during Xcode's build phase, translating `.urkel` files to `.swift` files behind the scenes without manual developer intervention.

## 2. Context
The ultimate "magic" of a DSL is when it feels like a native language feature. By writing an SPM Plugin, developers using Urkel simply drop `.urkel` files into their Xcode project, hit `Cmd + B`, and the Swift compiler instantly gains access to the generated Typestate boilerplate. The generated files live in Xcode's derived data, keeping the repository clean.

## 3. Acceptance Criteria
* **Given** an SPM package that depends on the Urkel toolchain.
* **When** the developer adds `.urkel` files to their target's directory.
* **And When** they compile the project.
* **Then** the SPM plugin automatically detects the `.urkel` files.
* **And Then** the plugin executes the `urkel generate` command for each file.
* **And Then** the resulting `+Generated.swift` files are placed in the plugin's work directory and successfully linked into the compiled Swift module.

## 4. Implementation Details
* In `Package.swift`, define an executable target for the CLI (`"UrkelCLI"`).
* Define a `plugin` target (`"UrkelPlugin"`) configured with `capability: .buildTool()`. Make the plugin depend on the executable target.
* Create `Plugins/UrkelPlugin/UrkelPlugin.swift`.
* Conform `UrkelPlugin` to `BuildToolPlugin`.
* Implement `createBuildCommands(context:target:)`.
* Iterate through `target.sourceFiles` looking for `.urkel` extensions.
* For each file, return a `.buildCommand` that:
  * Uses `context.tool(named: "UrkelCLI").path` as the executable.
  * Passes `generate [inputPath] --output [context.pluginWorkDirectory]` as arguments.
  * Declares the input and expected output paths so SPM knows when to skip redundant builds.

## 5. Testing Strategy
* **End-to-End Fixture Test:** Create a dummy Swift Package (a fixture) in the test directory that depends on the local Urkel plugin. Place a valid `.urkel` file in it. Use `Process` to run `swift build` on the dummy package. Assert that the build succeeds (meaning the plugin ran, generated valid Swift code, and the host compiled it).
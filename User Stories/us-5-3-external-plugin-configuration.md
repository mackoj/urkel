# US-5.3: External Generation Configuration

## 1. Objective
Allow downstream Swift packages to configure Urkel generation from a package-root JSON file so teams can control generation behavior, output names, and output locations without editing plugin code or the Urkel source tree.

## 2. Context
Urkel is most useful when each consuming package can declare how its generated code should behave. Teams often want different output file names, different output folders, or custom templates depending on the package or target that uses Urkel. A package-local configuration file keeps that behavior versioned with the consuming project and makes both the build tool plugin and the command plugin easier to adopt in real applications like `FolderWatch`.

## 3. Acceptance Criteria
* **Given** a Swift package that uses Urkel generation for one or more targets.
* **When** the package contains a configuration file at the package root or near a `.urkel` source file.
* **Then** the generator discovers that configuration without requiring changes to the plugin target itself.

* **Given** the configuration specifies an output file name.
* **When** Urkel generates code.
* **Then** the generated file is written with the configured name.

* **Given** the configuration specifies a custom output directory.
* **When** code generation runs.
* **Then** the generated file is emitted in the configured location relative to the active generator root.

* **Given** the configuration specifies a template, language, output extension, or source extension filter.
* **When** Urkel resolves generation settings.
* **Then** those values are passed through to the Urkel CLI and used consistently for generation.

* **Given** the configuration file is malformed.
* **When** the build runs.
* **Then** the generator reports a clear configuration error instead of silently falling back to defaults.

## 4. Implementation Details
* Extend the plugin configuration loader to search for an external JSON configuration file from the source file upward, then the target root, then the package root.
* Support a canonical config name such as `urkel-config.json`, while preserving any existing hidden-dotfile aliases needed for compatibility.
* Thread configuration values through the CLI invocation so the plugin does not duplicate generator behavior.
* Keep output path handling sandbox-safe for the build tool plugin, and package-safe for the command plugin, by resolving file names relative to the active generator root.
* Document the configuration schema in the package README and DocC so consuming packages can adopt it without reading plugin internals.

## 5. Testing Strategy
* Add fixture-based integration coverage using a downstream package that depends on the local Urkel checkout.
* Verify that a package-root config file is discovered and affects generated output.
* Confirm that a flat output filename works in SwiftPM’s plugin sandbox and in the command plugin flow.
* Validate that malformed config files surface a useful error during build.

# US-5.4: Checked-in Generated Source Workflow

## 1. Objective
Allow downstream packages to use the `UrkelGenerate` command plugin to write generated Swift directly into the package directory so the generated file can be checked into source control and compiled as part of the package.

## 2. Context
Some packages want generated code to live inside `Sources/...` instead of DerivedData. That makes the generated file easier to review, easier to commit, and easier to inspect inside Xcode. FolderWatch is the primary example of this flow: it keeps the `.urkel` source in the package and checks in the generated Swift alongside the rest of the module sources.

## 3. Acceptance Criteria
* **Given** a Swift package that includes `UrkelGenerate` in its package manifest.
* **When** a developer runs the command plugin with package-directory write permission.
* **Then** the plugin writes the generated Swift file into the package tree at the configured location.

* **Given** the package defines `urkel-config.json` at the package root.
* **When** the command plugin runs.
* **Then** the same configuration values used by the build tool plugin are honored.

* **Given** the package wants a checked-in file name such as `FolderWatchClient+Generated.swift`.
* **When** generation runs.
* **Then** the plugin writes that exact file name into `Sources/...` and the package compiles from the checked-in source.

* **Given** write permission is unavailable or the output path is invalid.
* **When** the command plugin runs.
* **Then** it reports a clear error instead of silently skipping generation.

## 4. Implementation Details
* Define a command plugin capability with `writeToPackageDirectory` permission.
* Invoke the existing `UrkelCLI generate` command so the command plugin does not duplicate generator logic.
* Reuse the same package-root configuration format as the build tool plugin.
* Document the checked-in source workflow in the README and generated-file integration guide.

## 5. Testing Strategy
* Run the command plugin against a real consumer package such as FolderWatch.
* Confirm the generated file appears in `Sources/FolderWatch/` after running the plugin.
* Build the consumer package with `xcodebuild` to verify the checked-in generated file compiles cleanly.

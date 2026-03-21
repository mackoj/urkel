# US-10.4: Config Parity Across CLI, Plugins, and Watch Mode

## 1. Objective
Unify behavior and config interpretation across `UrkelCLI`, build-tool plugin, command plugin, and watch service so generation is predictable in every entry point.

## 2. Context
Urkel has multiple generation paths. Small divergences in defaults or config search behavior increase user confusion and lead to inconsistent output locations and naming.

## 3. Acceptance Criteria
* **Given** a package-local `urkel-config.json`.
* **When** generation runs via CLI, `UrkelPlugin`, `UrkelGenerate`, or watch mode.
* **Then** effective configuration (output file, language/template, extension) is consistent.

* **Given** the same input machine and config.
* **When** generated from any entry point.
* **Then** output paths and filenames match documented behavior.

* **Given** invalid config.
* **When** generation starts.
* **Then** all entry points emit aligned, actionable diagnostics.

## 4. Implementation Details
* Extract shared config resolution logic into reusable Urkel core utilities.
* Add “effective config” debug output mode for troubleshooting.
* Document precedence order (source dir -> target dir -> package root -> cwd) in one place.

## 5. Testing Strategy
* Integration tests covering CLI + both plugins + watch with the same fixtures.
* Snapshot test of effective configuration resolution per fixture.

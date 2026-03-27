# US-15.1: Unified `@import` — Replace `@compose` with a Single Import Keyword

## 1. Objective

Replace the existing `@compose` keyword with a unified `@import` declaration that covers both **local imports** (sibling `.urkel` files in the same directory) and **external imports** (machines defined in a separate SPM dependency package) — using a single, consistent syntax distinguished only by the presence of a `from PackageName` clause.

## 2. Context

Urkel currently uses `@compose` for same-directory machine references, with auto-resolution by scanning sibling `.urkel` files. This implicit scanning is opaque — there is no way to tell from reading the file which machine comes from where, and it can silently pick up unintended `.urkel` files. It also has no mechanism for cross-package references.

The decision is to **remove `@compose` entirely** and replace it with `@import`, which unifies both resolution strategies under one explicit, readable keyword:

- `@import BLE` — **local import**: resolves `BLE.urkel` from sibling files in the same directory. Explicit and unambiguous.
- `@import BLE from BLEKit` — **external import**: resolves the `BLE` machine from the `BLEKit` SPM dependency package.

This mirrors the familiar `import` semantics developers already know from Swift (`import Foundation` vs a hypothetical `import Foundation from apple/swift-corelibs-foundation`), making the DSL immediately intuitive. `@compose` becomes a **deprecated alias** for `@import` (local) during a transition period, then removed.

## 3. Acceptance Criteria

* **Given** `@import BLE`, **when** the compiler processes the file, **then** it resolves `BLE` by finding `BLE.urkel` among sibling files in the same directory — identical behaviour to the old `@compose BLE`.

* **Given** `@import BLE from BLEKit`, **when** the compiler processes the file, **then** it resolves `BLE` from the `BLEKit` SPM dependency package's source directory, not the current directory.

* **Given** `@compose BLE` in an existing file, **when** the compiler processes it, **then** it emits a deprecation warning: `"@compose is deprecated; use '@import BLE' instead"` — and continues to work correctly.

* **Given** a machine using both `@import BLE` (local) and `@import Analytics from AnalyticsKit` (external) in the same file, **when** compiled, **then** both resolve correctly and independently.

* **Given** `@import BLE from BLEKit` where `BLEKit` is not in the target's SPM dependencies, **when** the build plugin runs, **then** it emits a clear diagnostic: `"Cannot find package 'BLEKit' in target dependencies"`.

* **Given** `@import BLE from BLEKit` where no `.urkel` file in `BLEKit` declares a machine named `BLE`, **when** the build plugin runs, **then** it emits: `"Machine 'BLE' not found in package 'BLEKit'"`.

* **Given** `@import BLE` where no sibling file named `BLE.urkel` exists, **when** the validator runs, **then** it emits: `"Cannot find local machine 'BLE' — expected a sibling file 'BLE.urkel'"`.

* **Given** an external import `@import BLE from BLEKit`, **when** Swift is generated, **then** `import BLEKit` is automatically added to the generated file's import block.

* **Given** the Visualizer (US-13.1), **when** a machine uses `@import BLE from BLEKit`, **then** the imported machine's states are rendered in a visually distinct style with a `BLEKit` package label, distinguishing it from locally-defined machines.

## 4. Implementation Details

* **DSL syntax — before and after:**
  ```
  # BEFORE (deprecated)
  machine Scale<ScaleContext>
  @compose BLE                      # implicit same-dir scan
  @compose Audio                    # implicit same-dir scan

  # AFTER (unified)
  machine Scale<ScaleContext>
  @import BLE                       # explicit local: resolves BLE.urkel in same directory
  @import Audio                     # explicit local: resolves Audio.urkel in same directory
  @import Analytics from AnalyticsKit  # explicit external: resolves from AnalyticsKit package
  ```

* **grammar.ebnf — replace `ComposeDecl` with `ImportDecl`:**
  ```ebnf
  ImportDecl   ::= "@import" Identifier ("from" Identifier)?
  ComposeDecl  ::= "@compose" Identifier   # deprecated alias, still parsed, emits warning
  ```

* **AST** — replace `composedMachines: [String]` on `MachineAST` with:
  ```swift
  struct MachineImport {
      let machineName: String
      let packageName: String?   // nil = local import
      let isDeprecatedCompose: Bool
  }
  var imports: [MachineImport]
  ```

* **Resolution strategy in `UrkelGenerator`:**
  - For `packageName == nil` (local): scan sibling `.urkel` files in the same directory, match by machine name. Error if not found.
  - For `packageName != nil` (external): delegate to the plugin (see below). The CLI receives a pre-resolved path via `--import Name:Path`.
  - Remove the implicit auto-scan fallback entirely. All machine references must be declared via `@import`.

* **Plugin resolution (`UrkelPlugin.swift`)** for external imports:
  - Walk `context.package.dependencies` to find the named package checkout.
  - Search its source targets for a `.urkel` file whose parsed machine name matches.
  - Pass `--import MachineName:/absolute/path/to/machine.urkel` to the CLI invocation.
  - Cache resolved paths keyed by `(machineName, packageName)` within the plugin build context.

* **Deprecation path for `@compose`:**
  1. This story: parse `@compose`, emit warning, treat as `@import` (local).
  2. Next major version: parser error with migration hint.
  3. Remove from grammar entirely.

* **Migration tooling** — add a `urkel migrate --fix compose` CLI subcommand that rewrites `@compose Foo` → `@import Foo` in-place across a directory tree.

## 5. Testing Strategy

* Parser: `@import BLE` (no package); `@import BLE from BLEKit` (with package); `@compose BLE` emits deprecation warning but succeeds; `@import` with neither name nor `from` → error.
* Resolution — local: sibling file found → resolves; sibling file missing → clear error.
* Resolution — external: package found → resolves; package not in deps → diagnostic; machine not in package → diagnostic.
* Circular import: `A @import B`, `B @import A` → error with cycle description.
* Emitter: external import adds `import BLEKit` to Swift output; local import does not add extra Swift imports.
* Migration command: `urkel migrate --fix compose` rewrites all `@compose` occurrences in fixture directory; verify output is valid `@import` syntax.
* Integration: update all existing examples (BluetoothScale, SmartWatch, MFSM) to use `@import`; verify they still compile and generate correctly.
* Regression: run full test suite after replacing `@compose` with `@import` in all fixtures — zero new failures.

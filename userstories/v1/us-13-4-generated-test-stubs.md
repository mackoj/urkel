# US-13.4: Generated Swift Test Path Stubs

## 1. Objective

Extend the Urkel compiler to optionally generate **Swift test stubs** — one `@Test` function per reachable path from `init` to any `final` state — giving developers a complete, compile-time-safe test scaffold that covers every possible route through their state machine.

## 2. Context

XState provides `@xstate/graph` as a separate package for model-based testing and path generation. For Urkel, this capability can be built in and made even more powerful: because the machine graph is fully known at compile time and the generated Swift types are compile-time safe, the test stubs themselves can be type-checked by the compiler. A developer who adds a new state and forgets to handle it in their tests will get a compile error, not a missing coverage report.

The generated stubs use Swift Testing (`@Test`, `#expect`) and integrate with the existing `DependencyClient.testValue` pattern from `swift-dependencies`.

This feature is opt-in, controlled by a `--generate-tests` flag on the CLI or a `generateTests: true` key in `urkel-config.json`.

## 3. Acceptance Criteria

* **Given** `urkel generate machine.urkel --generate-tests`, **when** run, **then** an additional `XxxMachineTests+Generated.swift` file is emitted alongside the regular generated files.

* **Given** a machine with N distinct paths from `init` to any `final` state, **when** test stubs are generated, **then** exactly N `@Test` functions are emitted, one per path.

* **Given** a generated test stub, **when** the developer opens it, **then** each function is named after its path (e.g., `test_Idle_load_Loading_ready_Playing`), contains a `// Path: Idle → load → Loading → ready → Playing` comment header, sets up `XxxClient.testValue`, and contains a `// TODO: assert` placeholder at each transition step.

* **Given** a machine where path count would exceed a configurable threshold (default: 100), **when** test generation runs, **then** it generates stubs only for the N shortest paths and emits a comment noting the total path count and the `--max-test-paths` option.

* **Given** the test stubs file already exists and is re-generated, **when** new paths are added to the machine, **then** new stubs are appended; existing stubs (identified by path name) are not overwritten, preserving any developer-written assertions.

* **Given** `generateTests: true` in `urkel-config.json`, **when** the build tool plugin runs, **then** the test stubs file is emitted into the plugin output directory alongside the regular generated files.

* **Given** a machine with guards (US-12.1), **when** test stubs are generated, **then** each path that traverses a guarded transition includes a comment `// guard 'guardName' must return true` at that step.

## 4. Implementation Details

* **New output file** — `XxxMachineTests+Generated.swift`. Emitted by a new `TestStubEmitter` (or as a fourth output of `SwiftCodeEmitter`).

* **Path enumeration** — reuse `GraphAnalyzer.allSimplePaths` from US-13.3. Apply the same `--max-depth` / `--max-test-paths` safeguards.

* **Stub template** (per path):
  ```swift
  // Path 2: Idle → load → Loading → failed → Error → retry → Loading
  @Test func test_Idle_load_Loading_failed_Error_retry_Loading() async throws {
      var client = VideoPlayerClient.testValue
      // TODO: configure client closures for this path

      // Step 1: Idle → load(url: URL) → Loading
      // guard 'isValidURL' must return true
      // action 'logLoad' would fire
      let loading = await client.makePlayer().load(url: /* provide value */)

      // Step 2: Loading → failed(error: Error) → Error
      let error = await loading.failed(error: /* provide value */)

      // Step 3: Error → retry → Loading
      // guard 'canRetry' must return true
      let loading2 = await error.retry()

      #expect(/* assert final state or side effects */)
  }
  ```

* **Merge strategy** — on regeneration, parse existing file for `// Path N:` comment headers. Match by path signature string. Only emit stubs for new paths (those whose signature doesn't already exist in the file). Never delete existing stubs.

* **Config key** — `urkel-config.json`:
  ```json
  {
    "generateTests": true,
    "maxTestPaths": 50
  }
  ```

* **`UrkelResolvedConfiguration`** — add `generateTests: Bool` (default `false`) and `maxTestPaths: Int` (default `100`).

## 5. Testing Strategy

* Unit-test `TestStubEmitter`: correct number of stubs for a small known machine; path names are valid Swift identifiers; guard annotations present when applicable.
* Merge strategy: second generation with one new path appends only the new stub.
* Compile check: generated stubs compile without errors against the corresponding generated machine (add to `generatedSwiftCompiles` test suite).
* Max-paths threshold: machine with > 100 paths emits only 100 stubs and a comment.
* Fixture: `VideoPlayerMachine` with 5-8 paths; verify stub output matches golden file.

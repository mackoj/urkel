# US-4.4: CLI Path Explorer & Generated Test Stubs

## Objective

Add a `urkel paths` CLI command that analyses a `.urkel` file and emits every
distinct path from the `init` state to any `final` state as structured JSON,
along with a `urkel test-stubs` command that generates Swift test function
skeletons — one per path — ready to be filled in with assertions. These two
commands close the loop between statechart design and test coverage.

## Background

A state machine's test coverage is best measured in *paths*, not in individual
state visits. For a machine with `N` states and `T` transitions, the number of
distinct `init → final` paths can be much larger than `N` — guards and branches
multiply the path count. Writing these tests by hand is error-prone and often
incomplete. By automating path enumeration from the validated AST, Urkel can
guarantee exhaustive path coverage scaffolding.

The path explorer also integrates naturally with Simulate mode (US-4.3): an
`Export Path` from the simulator produces a JSON object in exactly the same
format that `urkel paths` outputs, making it trivial to capture a manually
explored path and turn it into a test.

## Path JSON Format

```json
{
  "machine": "FolderWatch",
  "paths": [
    {
      "id": "path-1",
      "steps": [
        { "from": "Idle",     "event": "start",   "to": "Watching" },
        { "from": "Watching", "event": "stop",    "to": "Stopped"  }
      ],
      "guards": { "hasPermission": true }
    },
    {
      "id": "path-2",
      "steps": [
        { "from": "Idle",     "event": "start",   "to": "Watching" },
        { "from": "Watching", "event": "error",   "to": "Failed"   }
      ],
      "guards": {}
    }
  ]
}
```

Guard values are recorded as the assumed boolean that made that branch fire
(true for `[guard]`, false for `[!guard]`, winner for `[else]`).

## Acceptance Criteria

* **Given** `urkel paths FolderWatch/Sources/FolderWatch/folderwatch.urkel`,
  **when** the command runs, **then** it prints valid JSON to stdout listing
  every `init → final` path.

* **Given** a machine with a guard `[hasPermission]` that branches to two
  different destinations, **when** paths are enumerated, **then** both branches
  appear as separate path objects, each with the `guards` map recording the
  assumed value.

* **Given** `[else]` as the last guard, **when** paths are enumerated, **then**
  the `[else]` branch is represented as `"else": true` in the guards map.

* **Given** a machine with a cycle (`Error -> retry -> Loading -> failed -> Error`),
  **when** `urkel paths` runs, **then** cycles are detected and truncated —
  each cyclic edge is traversed at most once per path, preventing infinite
  enumeration.

* **Given** `--max-paths N` flag, **when** the path count exceeds `N`, **then**
  the first `N` paths are emitted and a warning is written to stderr:
  `"warning: truncated to N paths (machine has more)"`.

* **Given** `urkel test-stubs FolderWatch/Sources/FolderWatch/folderwatch.urkel`,
  **when** the command runs, **then** it writes a Swift file
  `FolderWatch+PathTests.swift` containing one `@Test` function per path, named
  after the path's steps, with placeholder `#expect(…)` assertions and a
  comment listing the full step sequence.

* **Given** a path JSON file produced by `urkel paths` or exported from Simulate
  mode, **when** passed to `urkel test-stubs --from-paths paths.json`, **then**
  test stubs are generated for exactly the paths in the JSON.

* **Given** `urkel paths --format mermaid`, **when** run, **then** the output
  is a Mermaid `stateDiagram-v2` block listing all paths as annotated transitions
  (useful for documentation).

## Implementation Details

* **Path enumeration algorithm**:
  - Build a directed graph from the validated `UrkelFile` AST.
  - For each guard clause, fork two sub-paths (guard true / guard false).
  - Perform DFS from the `init` state; record paths that reach a `final` state.
  - Cycle detection: track the current DFS path; if a state appears twice, skip
    that branch and record the partial path as `{ "cyclic": true }`.
  - For `always` eventless transitions, treat them as epsilon transitions and
    follow them immediately (no event label).

* **CLI commands**:
  - `urkel paths [--max-paths N] [--format json|mermaid] <file>`
  - `urkel test-stubs [--output <dir>] [--from-paths <json>] <file>`
  - Both commands parse the file and validate it first; abort on `.error`
    diagnostics before proceeding.

* **Test stub template** (per path):
  ```swift
  // Path: Idle → start → Watching → stop → Stopped
  @Test func path_Idle_start_Watching_stop_Stopped() async throws {
    // guards: {}
    let machine = FolderWatch(…)
    // TODO: fire events and assert state
    #expect(Bool(false), "Not yet implemented")
  }
  ```

* **Mermaid output** example:
  ```
  stateDiagram-v2
    [*] --> Idle
    Idle --> Watching : start
    Watching --> Stopped : stop
    Watching --> Failed : error
    Stopped --> [*]
    Failed --> [*]
  ```

* Add `urkel paths` and `urkel test-stubs` as subcommands to the existing
  `ArgumentParser`-based CLI entry point.

## Testing Strategy

* Create `Tests/UrkelTests/PathExplorerTests.swift`:
  - Flat machine (no guards): assert exactly 1 path if there is 1 init→final route.
  - Branching machine (2 guards): assert 4 paths (2² guard combinations).
  - Cyclic machine: assert cycles are truncated; no infinite loop.
  - `--max-paths 1`: assert only 1 path emitted and warning on stderr.
* Create `Tests/UrkelTests/TestStubGeneratorTests.swift`:
  - Generate stubs for `FolderWatch`; parse the output as Swift; assert it
    contains at least one `@Test` function per enumerated path.
* CLI integration: run `urkel paths` on each example file; assert exit code 0
  and valid JSON output.
* Mermaid format: assert output starts with `stateDiagram-v2` and contains
  correct state/event names.

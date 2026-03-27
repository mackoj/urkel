# US-13.3: CLI Path Explorer and Machine Linter

## 1. Objective

Add a `urkel simulate` CLI subcommand that enumerates all reachable paths through a `.urkel` machine, detects structural issues (dead states, unreachable states, missing `final`), and outputs machine health diagnostics — suitable for use in CI pipelines.

## 2. Context

The VS Code Simulate mode (US-13.2) provides an interactive walkthrough, but CI pipelines need a headless equivalent. Developers should be able to run `urkel simulate machine.urkel --lint` as a build step and get actionable output about structural problems — the same way `swiftlint` or `swift build` surfaces code issues.

Beyond linting, the `--all-paths` flag enumerates every path from `init` to any `final` state. This output feeds the generated test stub system (US-13.4) and enables coverage reporting.

This command is purely a graph analysis operation on the parsed `.urkel` AST — no Swift code generation involved.

## 3. Acceptance Criteria

* **Given** `urkel simulate machine.urkel`, **when** run interactively in a terminal, **then** it presents a text-based step-through: shows the current state and lists available events; the developer types an event name to advance.

* **Given** `urkel simulate machine.urkel --lint`, **when** run, **then** it exits with code `0` if no structural issues are found and code `1` if any issues exist, printing a human-readable report.

* **Given** a machine with a dead state (non-final, no outgoing transitions), **when** `--lint` runs, **then** it reports the dead state by name with a `[dead-state]` tag.

* **Given** a machine with an unreachable state (no path from `init`), **when** `--lint` runs, **then** it reports it with an `[unreachable]` tag.

* **Given** a machine with no `final` state, **when** `--lint` runs, **then** it emits a warning `[no-final-state]`.

* **Given** `urkel simulate machine.urkel --all-paths`, **when** run, **then** it outputs a JSON array of all simple paths from `init` to any `final` state (no cycles repeated).

* **Given** `urkel simulate machine.urkel --all-paths --output paths.json`, **when** run, **then** the paths are written to `paths.json` and the command exits cleanly.

* **Given** `urkel simulate machine.urkel --all-paths --format swift-stubs`, **when** run, **then** it outputs Swift test function stubs (see US-13.4) to stdout.

## 4. Implementation Details

* **CLI entry point** — add `simulate` subcommand to `UrkelCLI` alongside the existing `generate` command. Use `ArgumentParser` with:
  - Positional: `<source>` — path to `.urkel` file.
  - `--lint` — structural analysis mode.
  - `--all-paths` — enumerate all `init → final` paths.
  - `--output <path>` — write output to file instead of stdout.
  - `--format <json|swift-stubs>` — output format for `--all-paths`.
  - `--max-depth <n>` — limit path length to avoid exponential blowup on large machines (default: 50).

* **Graph algorithms** (`Sources/Urkel/GraphAnalyzer.swift` new file):
  - `reachableStates(from: init, graph)` — BFS/DFS.
  - `deadStates(graph)` — states with no outgoing transitions and not `final`.
  - `allSimplePaths(from: init, to: finals, graph, maxDepth)` — DFS with visited set; produces `[[StateName]]`.

* **Path JSON format:**
  ```json
  [
    {
      "id": "path-1",
      "steps": [
        { "state": "Idle",    "event": "load",   "params": ["url: URL"] },
        { "state": "Loading", "event": "ready",  "params": [] },
        { "state": "Playing.Buffering", "event": null, "params": [] }
      ]
    }
  ]
  ```

* **Interactive mode** — terminal REPL using `readLine()`. Print current state, available events with indices; accept index or event name input; handle `back`, `reset`, `quit`.

* **CI integration note** — document in README that `urkel simulate --lint` can be added as an SPM command plugin target or a pre-build script.

## 5. Testing Strategy

* Unit-test `GraphAnalyzer`: dead states detected; unreachable states detected; all-paths correct count for small known machines.
* Test `--lint` exit codes: healthy machine → 0; machine with dead state → 1.
* Test `--all-paths` JSON output is valid and paths are complete (start at `init`, end at `final`).
* Test `--max-depth` correctly truncates exponential machines.
* Integration: run `urkel simulate` against all example `.urkel` files; verify no unexpected lint errors.

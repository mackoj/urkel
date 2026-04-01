# US-4.2: Live Validation Highlighting in the Visualizer

## Objective

Surface the semantic diagnostics produced by `UrkelValidator` (US-3.4) directly
in the statechart diagram: dead states are highlighted in amber, unreachable
states in red, and validation errors/warnings are shown as tooltips and
reflected in the VS Code Problems panel — all updating live as the developer
edits the file.

## Background

The visualizer (US-4.1) renders the machine's structure. This story adds a
**static-analysis overlay** that visually communicates the health of the graph.
Because `UrkelValidator` already computes dead states, unreachable states, and
structural errors with `SourceRange` locations, the extension only needs to wire
those diagnostics into the webview and VS Code's native `DiagnosticCollection`.

This closes the feedback loop: a developer who accidentally leaves a state
unreachable sees it highlighted in red in the diagram *and* a squiggle in the
source file, without having to run any build.

## Acceptance Criteria

* **Given** a machine where `StateB` has no path from `init`, **when** the
  diagram renders, **then** `StateB`'s rectangle is outlined in red and has a
  tooltip: `"Unreachable: no path from init"`.

* **Given** a non-final state with no outgoing transitions, **when** rendered,
  **then** that state is outlined in amber with tooltip: `"Dead state: no
  outgoing transitions"`.

* **Given** a transition that references an undeclared state, **when** the file
  is saved, **then** a red squiggle appears in the VS Code editor at the
  undeclared name, and the Problems panel shows the error with file, line, and
  column.

* **Given** multiple validation errors in the same file, **when** the diagram
  is open, **then** every affected state/transition in the diagram carries its
  own highlight and tooltip — multiple errors are shown simultaneously.

* **Given** the developer fixes the error (declares the missing state), **when**
  the file is saved and re-validated, **then** the highlight and squiggle are
  cleared within 500 ms.

* **Given** a `.warning`-severity diagnostic (e.g. dead state), **when** shown
  in the Problems panel, **then** it has a ⚠️ icon (not ❌); in the diagram,
  amber (not red) is used.

* **Given** a `.error`-severity diagnostic, **when** shown, **then** it has a ❌
  icon; in the diagram, red is used.

* **Given** the diagram is closed while a file has errors, **when** the
  developer re-opens the diagram, **then** the error highlights are immediately
  present (not deferred until the next save).

## Implementation Details

* **Extension side** additions to `VisualizerPanel.ts`:
  - On each file update, call `UrkelParser.parse()` + `UrkelValidator.validate()`
    via the LSP server (preferred) or by spawning `urkel validate --json <file>`
    as a child process. Receive a `Diagnostic[]` JSON array.
  - Convert `Diagnostic[]` to a `vscode.DiagnosticCollection` and publish it —
    this drives editor squiggles and the Problems panel.
  - Also post `{ type: 'diagnostics', items: Diagnostic[] }` to the webview.

* **Webview side** additions in `visualizer.js`:
  - On receiving `{ type: 'diagnostics' }`, index diagnostics by affected node
    name (state name or source state of a transition).
  - Apply CSS classes: `.dead-state` (amber border + fill), `.unreachable-state`
    (red border + fill) to matching SVG elements.
  - Attach a `<title>` element (SVG native tooltip) to each highlighted node
    containing the diagnostic message.
  - Clear all highlight classes before applying new ones on each update.

* **`urkel validate --json`** CLI subcommand (if the webview cannot use the LSP):
  - Accepts a file path; prints `[{ "severity": "error"|"warning", "code": "…",
    "message": "…", "range": { "start": { "line": N, "column": N }, "end": { … } } }]`
    to stdout.
  - Exit code `0` on success, `1` if any `.error` diagnostics are present.

* **Colour palette** (respects VS Code theme variables):
  - Dead (warning): `--vscode-editorWarning-foreground` border, light amber fill.
  - Unreachable (error): `--vscode-editorError-foreground` border, light red fill.

## Testing Strategy

* **Webview JS unit tests** (Vitest):
  - `applyDiagnostics(graph, diagnostics)` colours the correct nodes.
  - Clearing: after calling with an empty array, no nodes are highlighted.
* **Integration**:
  - Fixture file with a dead state; open diagram; assert amber highlight present.
  - Fix dead state (add a transition); save; assert amber highlight removed.
  - Fixture file with an unreachable state; assert red highlight.
* **Problems panel**: verify VS Code `DiagnosticCollection` is updated with
  correct file/line/column; use the VS Code Extension Test framework.
* **CLI `--json`**: call `urkel validate --json` on valid and invalid fixtures;
  assert correct JSON and exit codes.

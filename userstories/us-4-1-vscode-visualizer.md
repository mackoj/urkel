# US-4.1: VS Code Statechart Visualizer — Design Mode

## Objective

Add a **live statechart diagram** to the Urkel VS Code extension
(`urkel-vscode-lang`) that renders any open `.urkel` file as an interactive,
auto-updating statechart in a side panel. The diagram shows states, transitions,
compound/parallel nesting, and entry/exit hooks — giving developers an
immediate visual understanding of their machine's structure.

## Background

XState's biggest DX advantage is the Stately Studio visual editor: developers
see the machine as a diagram and instantly understand structure, spot dead
states, and communicate intent to stakeholders. Urkel's `.urkel` DSL is a
complete static graph description — no runtime is needed to render it.

The visualizer is purely a tooling concern that lives in the VS Code extension.
It reads the `.urkel` file (via the existing LSP parse results or a direct file
read), converts it to a graph data structure, and renders it in a VS Code
`WebviewPanel` using a hierarchical layout engine. It updates live as the
developer types.

This story covers **Design mode** (static diagram). Simulate mode is US-4.3.
Dead/unreachable state highlighting is US-4.2.

## Acceptance Criteria

* **Given** an open `.urkel` file, **when** the developer runs the
  `Urkel: Open Visualizer` command (or clicks the toolbar icon), **then** a
  panel opens beside the editor showing a statechart diagram of the machine.

* **Given** the diagram is open and the developer saves the `.urkel` file,
  **when** the save completes, **then** the diagram updates within 500 ms to
  reflect the new structure — no manual refresh required. (Debounce live edits
  to 300 ms.)

* **Given** a flat machine (no compound/parallel states), **when** rendered,
  **then**:
  - Each `state` appears as a rounded rectangle labelled with its name.
  - The `init` state has a filled-circle entry arrow.
  - Each `final` state has a double border.
  - Each transition is a directed arrow labelled `event [guard] / action`.
  - Timer transitions are labelled `after(Ns)`.
  - `always` transitions are labelled `always [guard]` or `always`.
  - Internal (`-*>`) transitions are shown as looping arrows on the same state,
    labelled with a `⟳` prefix to distinguish them from standard transitions.

* **Given** a machine with compound states, **when** rendered, **then** child
  states appear nested inside their parent container rectangle with a visible
  label for the compound state name.

* **Given** a machine with a `@parallel` block, **when** rendered, **then**
  regions appear inside a dashed-border container, separated by dashed
  vertical dividers, each region labelled.

* **Given** the developer clicks a state or transition in the diagram, **when**
  the source `.urkel` file is open, **then** the editor scrolls to and
  highlights the corresponding declaration (using `SourceRange` from the AST).

* **Given** the machine has an `@import` sub-machine, **when** rendered,
  **then** the imported machine is shown as a collapsed node with a `⤢` icon
  indicating it expands to a separate machine.

## Implementation Details

* **Extension side** (`urkel-vscode-lang`):
  - Register `urkel.openVisualizer` command in `package.json`.
  - Create `VisualizerPanel.ts` using `vscode.WebviewPanel` with
    `enableScripts: true` and `retainContextWhenHidden: true`.
  - On file open and on `onDidSaveTextDocument` (plus debounced
    `onDidChangeTextDocument` at 300 ms), send the current file content to the
    webview via `panel.webview.postMessage({ type: 'update', source })`.
  - On `{ type: 'navigate', range }` messages from the webview, call
    `vscode.window.showTextDocument` and set the selection to the range.

* **Webview side** (bundled `visualizer.html` + `visualizer.js`):
  - Parse the `.urkel` source text to a **graph JSON** format:
    ```json
    {
      "machine": "FolderWatch",
      "states": [
        { "id": "Idle", "kind": "init", "range": { … } },
        { "id": "Watching", "kind": "state", "range": { … } },
        { "id": "Stopped", "kind": "final", "range": { … } }
      ],
      "transitions": [
        { "from": "Idle", "event": "start", "to": "Watching", "range": { … } }
      ],
      "compounds": [ … ],
      "parallels": [ … ]
    }
    ```
    The JS parser mirrors the EBNF grammar enough to extract graph structure; it
    need not be a full parser (a structural extractor is sufficient here; the
    full parser lives in the Swift library).
  - Layout using [`elkjs`](https://github.com/kieler/elkjs) in hierarchical
    (`layered`) mode. ELK handles compound and parallel nesting natively.
  - Render with SVG (plain DOM manipulation or a thin `d3-dag` wrapper). No
    heavy frameworks.
  - Style with VS Code CSS variables (`--vscode-editor-background`,
    `--vscode-editor-foreground`, etc.) so the diagram respects the current
    theme automatically.
  - Send `{ type: 'navigate', range }` to the extension when a state or
    transition is clicked.

* **Toolbar** — a VS Code editor title action button (📊 icon) opens the panel
  when any `.urkel` file is active.

## Testing Strategy

* **Manual integration**: open each example `.urkel` file; verify diagram
  renders the correct number of states and transitions.
* **Automated JS unit tests** (Vitest):
  - Graph extractor: verify correct node/edge JSON for flat, compound, and
    parallel machines.
  - Click → navigate message: assert the correct `range` is posted.
* **Theme tests**: switch VS Code to Light theme while diagram is open; verify
  no hardcoded colours.
* **Live update**: edit a state name in `.urkel`, save; verify diagram reflects
  the change within 1 second.
* **Performance**: open a machine with 30+ states; verify the diagram renders
  in under 2 seconds.

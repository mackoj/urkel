# US-13.1: VS Code Statechart Visualizer

## 1. Objective

Add a **design-time statechart diagram** to the Urkel VS Code extension (`urkel-vscode-lang`) that renders any open `.urkel` file as an interactive, auto-updating statechart diagram in a side panel.

## 2. Context

XState's biggest DX advantage is the Stately Studio visual editor — developers can see their state machine as a diagram and immediately understand structure, spot dead states, and communicate intent to stakeholders. Urkel's `.urkel` DSL is already a complete static description of the graph; no runtime is needed to render it. This means the visualizer is purely a tooling concern and can be built entirely in the VS Code extension without touching the Swift compiler.

The visualizer reads the `.urkel` file (via the existing LSP parse results or a direct file read), converts it to a graph data structure, and renders it in a VS Code `WebviewPanel` using a graph layout library. It updates live as the developer types.

This is the highest-leverage single DX improvement for Urkel — it closes the most visible gap with XState/Stately with no changes to the Swift compiler or generated code.

## 3. Acceptance Criteria

* **Given** an open `.urkel` file, **when** the developer runs the `Urkel: Open Visualizer` command (or clicks a toolbar icon), **then** a side panel opens showing a statechart diagram of the machine.

* **Given** the diagram is open and the developer edits the `.urkel` file, **when** the file is saved (or after a short debounce), **then** the diagram updates to reflect the new structure without requiring a manual refresh.

* **Given** a machine with states and transitions, **when** the diagram renders, **then** each state appears as a rounded rectangle, each transition as a labelled directed arrow, the initial state has an entry marker, and final states have a double border.

* **Given** a machine with compound states (US-12.3), **when** rendered, **then** child states appear nested inside their parent's container rectangle.

* **Given** a machine with a parallel state (US-12.4), **when** rendered, **then** regions appear inside a dashed-border container, separated by dashed dividers.

* **Given** a machine with a dead state (no outgoing transitions and not `final`), **when** rendered, **then** that state is highlighted in amber with a tooltip explaining the issue.

* **Given** an unreachable state (no path from `init`), **when** rendered, **then** that state is highlighted in red.

* **Given** the developer clicks a state or transition in the diagram, **when** the `.urkel` source file is open, **then** the editor scrolls to and highlights the corresponding declaration.

## 4. Implementation Details

* **Extension side** (`urkel-vscode-lang`):
  - Register a `urkel.openVisualizer` command in `package.json`.
  - Create a `VisualizerPanel` class using `vscode.WebviewPanel` with `enableScripts: true`.
  - On activation and on each `onDidChangeTextDocument` (debounced 300 ms), send the current file content to the webview via `panel.webview.postMessage`.

* **Webview side** (bundled HTML + JS):
  - Parse the `.urkel` text to a graph JSON (states + transitions). Can reuse a lightweight JS port of the Urkel grammar, or use a regex-based extractor sufficient for visualization.
  - Layout using [`elkjs`](https://github.com/kieler/elkjs) (hierarchical layout, handles nested/parallel) or `dagre`.
  - Render with SVG (plain or via a thin wrapper like `d3-dag`). No heavy frameworks needed.
  - Post `{ type: 'clickState', name }` / `{ type: 'clickTransition', ... }` messages back to the extension to trigger source navigation.

* **Dead/unreachable detection** — computed from the graph structure before rendering (BFS from `init` for reachability; check out-degree for dead states).

* **Styling** — match VS Code theme colours via CSS variables (`--vscode-editor-background`, etc.).

## 5. Testing Strategy

* Manual integration test: open each example `.urkel` file; verify diagram renders correctly.
* Automated: a Jest/Vitest test suite for the graph-extraction JS that verifies correct node/edge output for flat, compound, and parallel machines.
* Dead state detection: fixture with an intentional dead state; verify amber highlight.
* Unreachable detection: fixture with unreachable state; verify red highlight.
* Live update: edit state name in `.urkel` while diagram is open; verify diagram updates within 1 second.

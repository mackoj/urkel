# US-4.3: Simulate Mode

## Objective

Add an interactive **Simulate mode** to the Urkel VS Code visualizer that lets
developers step through all possible state transitions manually — clicking
events to fire them, toggling guards, stepping back, and exploring every
reachable path — entirely from the static `.urkel` file, without running any
Swift code.

## Background

XState's Stately Studio has two modes: **Design** (static diagram) and
**Simulate** (interactive walkthrough). Simulate mode is one of its most
compelling DX features because it lets you verify that a machine behaves as
intended *before* writing any implementation, discover impossible states and
missing transitions, and generate concrete test scenarios by recording a
simulation session.

Because Urkel's `.urkel` file is a complete static graph, simulation requires
zero runtime. The VS Code webview acts as a full interpreter of the graph in
JavaScript. Guards are represented as toggleable checkboxes (their runtime
value is unknown statically); actions are shown as "would fire" annotations.

This story builds directly on US-4.1 (Design mode) and US-4.2 (diagnostics) —
Simulate mode is an additional toggle within the same panel.

## Acceptance Criteria

* **Given** the Visualizer panel is open in Design mode, **when** the developer
  clicks the `Simulate` toolbar button, **then** the panel enters Simulate mode:
  the `init` state is highlighted as the current state, and a sidebar lists all
  available events from that state.

* **Given** Simulate mode is active and an event is listed, **when** the
  developer clicks it, **then** the current-state highlight moves to the
  destination state and the step is recorded in the history timeline.

* **Given** a guarded transition `[guardName]` in the available events list,
  **when** the guard checkbox is unticked, **then** the transition is
  greyed-out and cannot be fired; when ticked, it becomes available.

* **Given** an `[else]` guard branch, **when** all preceding guards for the
  same `(source, event)` are unticked, **then** the `[else]` branch becomes
  the active option.

* **Given** a transition with actions (`/ cleanup, log`), **when** it is fired,
  **then** the sidebar shows `"(would fire: cleanup, log)"` next to the event
  as an informational annotation.

* **Given** the developer has taken at least one step, **when** they click
  `Step Back`, **then** the machine reverts to the previous state and the last
  step is removed from the history timeline.

* **Given** the developer clicks `Reset`, **then** the machine returns to the
  `init` state, guard toggles reset to their default state, and the history
  clears.

* **Given** the machine reaches a `final` state, **when** the transition fires,
  **then** the panel shows a completion banner with the output type (if any)
  and the full path taken.

* **Given** a simulation session has been recorded, **when** the developer
  clicks `Export Path`, **then** a JSON file is written (or copied to clipboard)
  in the format used by US-4.4:
  ```json
  {
    "machine": "VideoPlayer",
    "path": [
      { "from": "Idle",    "event": "load",  "to": "Loading" },
      { "from": "Loading", "event": "ready", "to": "Playing" }
    ]
  }
  ```

* **Given** the underlying `.urkel` file changes while Simulate mode is active,
  **when** the re-parse completes, **then** Simulate mode resets to `init` with
  an inline notification: `"Machine definition changed — simulation reset"`.

* **Given** a compound state, **when** simulating, **then** events on the
  parent compound state are available when the machine is in any child state
  (hierarchical event handling).

## Implementation Details

* **Mode toggle** — a `Simulate` button in the webview toolbar switches between
  `design` and `simulate` modes. The webview keeps a
  `SimulatorState { currentState: string, history: Step[], guardOverrides: Map<string, boolean> }`
  object in JS memory.

* **Available events computation**:
  ```js
  function availableTransitions(state, graph) {
    // includes transitions from `state` AND from any compound ancestor
    // excludes ->> output event declarations (no destination)
    // respects guard overrides
  }
  ```

* **Guard toggle UI** — each guarded transition shows a labelled checkbox
  `[guardName] ☐`. The `SimulatorState.guardOverrides` map records the
  current toggle value; the `[else]` branch auto-enables when all preceding
  guards are off.

* **History timeline** — a scrollable `<ul>` below the diagram listing
  `Source → event → Dest` steps. Clicking a step jumps back to that point
  (equivalent to `Step Back` N times).

* **Extension message types** added to the existing protocol:
  - `{ type: 'simulatorStep', from, event, to }` — sent to extension for
    telemetry/logging.
  - `{ type: 'simulatorExport', path }` — triggers file-save or clipboard write.

* **Performance** — cap history at 500 steps (virtualise the list if longer).

## Testing Strategy

* **Webview JS unit tests** (Vitest):
  - `availableTransitions(state, graph)` returns correct events for flat and
    compound machines.
  - Guard toggle enables/disables correct transitions; `[else]` auto-activates.
  - Step advances `currentState`; step-back reverts.
  - Reset returns to `init` and clears history.
  - Final state reached: completion indicator fires.
* **Compound state**: event on parent fires while in child; parent entry/exit
  annotations are shown correctly.
* **Export**: path JSON is valid, complete, and parseable.
* **Machine change reset**: send a new `update` message while in simulate mode;
  assert state resets to `init`.
* **Cycle guard**: machine with `Error → retry → Loading → failed → Error`;
  step through 10 cycles; assert history length equals 20 (not deduplicated).

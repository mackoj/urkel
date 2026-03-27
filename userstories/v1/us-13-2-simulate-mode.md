# US-13.2: VS Code Simulate Mode

## 1. Objective

Add an interactive **Simulate mode** to the Urkel VS Code visualizer that lets developers walk through all possible state transitions manually — clicking events to fire them, stepping back, and exploring every reachable path — entirely from the static `.urkel` file without running any Swift code.

## 2. Context

XState's Stately Studio has two modes: **Design** (static diagram) and **Simulate** (interactive walkthrough). Simulate mode is one of XState's most compelling DX features because it lets you:

1. Verify the machine behaves as intended before writing any implementation.
2. Discover impossible states and missing transitions.
3. Communicate behaviour to non-technical stakeholders interactively.
4. Generate concrete test scenarios by recording a simulation session.

Because Urkel's `.urkel` file is a complete static graph, simulation requires zero runtime. The VS Code webview can act as a full interpreter of the graph entirely in JavaScript. Guards are represented as toggleable checkboxes (since their runtime value is unknown); actions are listed as "would fire" annotations.

This story builds on top of the Visualizer (US-13.1) — Simulate mode is an additional toggle within the same panel.

## 3. Acceptance Criteria

* **Given** the Visualizer panel is open, **when** the developer clicks a `Simulate` toggle button, **then** the panel enters Simulate mode: the current state is highlighted, and a sidebar shows the list of available events from that state.

* **Given** Simulate mode is active, **when** the developer clicks an available event, **then** the current state highlight moves to the destination state and the event is recorded in a history timeline.

* **Given** a guarded transition, **when** it appears in the available events list, **then** a checkbox or toggle next to it represents the guard condition; the transition is only available when the checkbox is ticked.

* **Given** the developer has taken several steps, **when** they click `Step Back`, **then** the machine rewinds to the previous state.

* **Given** the developer clicks `Reset`, **when** confirmed, **then** the machine returns to the `init` state and the history clears.

* **Given** the developer reaches a `final` state, **when** the simulation ends, **then** the panel shows a completion indicator and the full path taken.

* **Given** a simulation session has been recorded (sequence of states + events), **when** the developer clicks `Export Path`, **then** a JSON or Swift stub is copied to the clipboard or written to a file (feeds into US-13.4 test stubs).

* **Given** the underlying `.urkel` file changes while Simulate mode is active, **when** the new parse completes, **then** Simulate mode resets to `init` with a notification that the machine definition changed.

## 4. Implementation Details

* **Mode toggle** — a toolbar button in the visualizer webview switches between `design` and `simulate` mode. The webview maintains a `SimulatorState { currentState, history }` object in JS memory.

* **Available events computation** — from `currentState`, filter all transitions where `from === currentState` (or where `from` is a parent of `currentState` for compound states). Display event names with their parameters listed as placeholders.

* **Guard checkboxes** — each guarded transition has an inline toggle. The JS simulator respects these as boolean overrides. A small `[guard: name]` label is shown next to each toggle for clarity.

* **History timeline** — a scrollable list of `State → event → State` steps shown below or beside the diagram. Clicking a history entry jumps back to that point (this is equivalent to `Step Back` N times).

* **Actions annotation** — transitions and states with actions show a `/ action` label in the event list as "(would fire: actionName)" — purely informational.

* **Export Path** — serialises the history as:
  ```json
  {
    "machine": "VideoPlayer",
    "path": [
      { "from": "Idle", "event": "load", "to": "Loading" },
      { "from": "Loading", "event": "ready", "to": "Playing.Buffering" }
    ]
  }
  ```

* **Extension message protocol** — reuse the existing `postMessage` channel from US-13.1. Add message types: `{ type: 'simulatorStep', from, event, to }` and `{ type: 'simulatorExport', path }`.

## 5. Testing Strategy

* Webview JS unit tests: `availableTransitions(state, graph)` returns correct events; step advances state; step back reverts; guard toggle enables/disables transition.
* Compound state: event on parent matches from child; parent entry/exit annotations shown correctly.
* Parallel state: both regions advance; event only moves handling region.
* Final state reached: completion indicator fires.
* Export: path JSON is valid and complete.
* Edge case: machine with a cycle (e.g., `Error -> retry -> Loading -> failed -> Error`); ensure history doesn't infinitely grow (cap at N steps or virtualize).

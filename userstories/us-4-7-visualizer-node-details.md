# US-4.7: Visualizer — Augmented Node Details

## Objective

Enrich state nodes and edges in the visualizer with contextual information
currently invisible: state-carried data params, entry/exit hook indicators,
`@history` markers, fork sub-machine spawn markers, and sub-machine import
link badges. Edges should show guard expressions and parameter names.

## Background

The current visualizer renders states as plain boxes with just a name and
kind indicator. Urkel has rich per-state metadata that is invisible:

| Metadata | Example DSL | Currently shown |
|----------|------------|-----------------|
| Init state params | `init(scaleUUIDs: [String]) Off` | ❌ |
| Final state output | `final(weight: Double) Measurement` | ❌ |
| Entry hook | `@entry Tare / performTare` | ❌ |
| Exit hook | `@exit Syncing / hideSyncIndicator` | ❌ |
| History | `state Playing @history { ... }` | ❌ |
| Fork target | `WakingUp -> hardwareReady -> Tare => BLE.init` | ❌ |
| Sub-machine import | `@import BLEPeripheral` | ❌ |
| Guard condition | `[bleConnected]` | partial |
| Transition params | `weightLocked(weight: Double)` | label only |

## Design

### State node anatomy

```
┌─────────────────────────────┐
│ ↺ Tare          @entry ⚡   │  ← @history indicator + entry hook badge
│─────────────────────────────│
│ in: scaleUUIDs: [String]    │  ← init params (init states only)
│ out: weight: Double         │  ← output params (final states only)
└─────────────────────────────┘
```

- `↺` shown when `@history` applies to the state
- `⚡` shown when `@entry` hook exists; `⬡` when `@exit` hook exists
- Param lines shown only when non-empty (collapsed for plain states)
- Clicking a node opens a detail popover with full info

### Edge annotations

- Guard label shown in `[ ]` below the event name
- Param list shown in `( )` after the event name  
- Fork badge `⇒ SubMachine` shown on fork transitions

### Sub-machine panel

A collapsible sidebar panel lists all `@import` declarations with a
"View diagram" link that (if the HTML file exists) opens it.

## GraphJSON changes

```swift
public struct GraphNode: Sendable, Codable {
    // existing fields …
    public let params: [String]        // NEW: "label: Type" strings
    public let entryHooks: [String]    // NEW: action names
    public let exitHooks: [String]     // NEW: action names
    public let hasHistory: Bool        // NEW
}

public struct GraphEdge: Sendable, Codable {
    // existing fields …
    public let params: [String]        // NEW: event param "label: Type" strings
    public let forkTarget: String?     // NEW: "MachineName.StateName" if fork
}
```

## Acceptance Criteria

* **Given** `init(scaleUUIDs: [String]) Off`, **when** rendered, **then**
  the `Off` node shows `in: scaleUUIDs: [String]`.

* **Given** `final(weight: Double, metrics: BodyMetrics) Measurement`,
  **when** rendered, **then** the node shows `out: weight: Double, metrics: BodyMetrics`.

* **Given** `@entry Tare / performTare`, **when** rendered, **then**
  `Tare` node shows a `⚡` badge and `performTare` in its detail view.

* **Given** `WakingUp -> hardwareReady -> Tare => BLE.init`, **when**
  rendered, **then** the edge shows a `⇒ BLE` fork badge.

* **Given** a guard `[bleConnected]`, **when** rendered, **then** the
  edge label shows `hardwareReady [bleConnected]`.

* **Given** a machine with no special metadata, **when** visualised,
  **then** nodes render as compact plain boxes (no extra lines shown).

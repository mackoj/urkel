# US-4.5: Visualizer — Parallel Regions

## Objective

Render `@parallel` blocks in the standalone HTML visualizer as labelled
swimlane containers with their regions shown side-by-side inside a bounding
box, so the parallel execution semantics are visually obvious.

## Background

Currently `@parallel Processing` is completely invisible in the visualizer —
only the outer machine states appear. The parallel block is parsed into
`file.parallels` and its regions into `RegionDecl.states` /
`RegionDecl.transitions`, but `GraphJSON.from()` never reads `file.parallels`.

Parallel regions are the hardest construct to visualise correctly because:
- The outer machine has a state that *represents* the whole parallel block
  (e.g. `Processing`)
- Inside that state, N regions run concurrently, each with its own sub-states
- `@on Parallel::done` fires when **all** regions reach their final sub-state

## Design

```
┌─────────────────────────────────────────────────────────────┐
│ Processing  (@parallel)                                      │
│  ┌────────────────────┐   ┌────────────────────────────────┐│
│  │ Rendering          │   │ SpoolCheck                     ││
│  │ ○ Queued           │   │ ○ Checking                     ││
│  │   Rendering        │   │   Ready                        ││
│  │ ◉ Rendered         │   │ ◉ Cleared                      ││
│  └────────────────────┘   └────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

- The outer state node for `Processing` is replaced by the swimlane container
- Each region is a labelled column with its own state nodes and transitions
- The outer `@on Processing::done -> Done` arrow exits the container box

## GraphJSON changes

Add parallel region data to `GraphJSON`:

```swift
public struct RegionGraph: Sendable, Codable {
    public let parallelState: String   // outer state name (e.g. "Processing")
    public let regionName: String
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]
}

public struct GraphJSON: Sendable, Codable {
    public let machine: String
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]
    public let regions: [RegionGraph]  // NEW
}
```

## JS/HTML changes

- When `GRAPH.regions` is non-empty, lay out the parallel container state as
  a wide swimlane box in the depth layer it occupies
- Each region column is rendered inside the swimlane with its own mini-layout
- Region-internal edges are drawn only within the swimlane
- Edges leaving the swimlane (`@on Parallel::done`) are drawn from the
  swimlane box boundary

## Acceptance Criteria

* **Given** `print-job.urkel`, **when** visualised, **then** `Processing`
  renders as a swimlane with `Rendering` and `SpoolCheck` columns inside.

* **Given** a region column, **when** rendered, **then** its states show
  correct init (●) / final (◉) indicators.

* **Given** `@on Processing::done → Done`, **when** rendered, **then**
  an arrow exits the swimlane box and points to `Done`.

* **Given** a machine with no `@parallel`, **when** visualised, **then**
  the output is unchanged (backward-compatible).

# US-4.6: Visualizer — Compound States

## Objective

Render compound states in the standalone HTML visualizer as nested boxes,
with child states drawn inside the parent state boundary, matching the
hierarchical semantics of HSMs (hierarchical state machines).

## Background

Compound states (`state Playing { Buffering; Streaming; Paused }`) are parsed
into `CompoundStateDecl` with `children: [SimpleStateDecl]` and
`innerTransitions: [TransitionStmt]`. Currently `GraphJSON` uses only
`file.simpleStates` (flattened), so compound structure is invisible.

The visual result should resemble classic statechart notation where the child
states appear as smaller boxes inside the parent boundary.

## Design

```
┌──────────────────────────────────────────────────┐
│ Playing  (@history ↺)                            │
│                                                  │
│  ┌──────────┐  ──bufferReady──▶  ┌────────────┐ │
│  │ Buffering│◀──bufferUnderrun──  │ Streaming  │ │
│  └──────────┘                    └────────────┘ │
│                  ┌────────┐                     │
│                  │ Paused │                     │
│                  └────────┘                     │
└──────────────────────────────────────────────────┘
        │ stop                │ error
        ▼                     ▼
     Stopped                 Idle
```

- The compound state node becomes a container box, not a plain node
- Child states are laid out inside using a mini BFS layout
- Inner transitions (`bufferReady`, `pause`, `resume`) are drawn inside
- Outer transitions (`stop`, `error`) originate from the container boundary
- `@history` indicator shown in the corner (↺)
- Parent-level transitions that apply to all children are drawn once from
  the container, not replicated per child

## GraphJSON changes

```swift
public struct CompoundGraph: Sendable, Codable {
    public let parentState: String
    public let hasHistory: Bool
    public let childNodes: [GraphNode]
    public let innerEdges: [GraphEdge]
}

public struct GraphJSON: Sendable, Codable {
    public let machine: String
    public let nodes: [GraphNode]          // outer states only
    public let edges: [GraphEdge]          // outer transitions + compound→outer
    public let regions: [RegionGraph]      // from US-4.5
    public let compounds: [CompoundGraph]  // NEW
}
```

## Acceptance Criteria

* **Given** `media-player.urkel` (has `Playing { Buffering; Streaming; Paused }`),
  **when** visualised, **then** `Playing` renders as a container box with
  the three child states inside.

* **Given** inner transitions (`bufferReady`, `pause`), **when** rendered,
  **then** they are drawn inside the `Playing` container.

* **Given** a parent-level transition (`Playing → stop → Stopped`),
  **when** rendered, **then** a single arrow exits the container boundary.

* **Given** a compound state with `@history`, **when** rendered, **then**
  a `↺` indicator appears in the state node header.

* **Given** a machine with no compound states, **when** visualised, **then**
  output is unchanged (backward-compatible).

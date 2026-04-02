import Foundation
import Urkel

public struct GraphNode: Sendable, Codable {
    public let id: String
    public let label: String
    public let kind: String

    public init(id: String, label: String, kind: String) {
        self.id = id
        self.label = label
        self.kind = kind
    }
}

public struct GraphEdge: Sendable, Codable {
    public let id: String
    public let source: String
    public let target: String
    public let label: String
    public let guardLabel: String?

    public init(id: String, source: String, target: String, label: String, guardLabel: String? = nil) {
        self.id = id
        self.source = source
        self.target = target
        self.label = label
        self.guardLabel = guardLabel
    }
}

/// One swimlane region inside a `@parallel` block.
public struct RegionGraph: Sendable, Codable {
    /// The outer state name that owns this parallel block (e.g. `"Processing"`).
    public let parallelState: String
    public let regionName: String
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]

    public init(parallelState: String, regionName: String, nodes: [GraphNode], edges: [GraphEdge]) {
        self.parallelState = parallelState
        self.regionName = regionName
        self.nodes = nodes
        self.edges = edges
    }
}

/// A compound (hierarchical) state with nested children.
public struct CompoundGraph: Sendable, Codable {
    /// The name of the compound state container (e.g. `"Active"`).
    public let parentState: String
    /// `true` when the compound state carries a `@history` modifier.
    public let hasHistory: Bool
    public let childNodes: [GraphNode]
    public let innerEdges: [GraphEdge]

    public init(parentState: String, hasHistory: Bool, childNodes: [GraphNode], innerEdges: [GraphEdge]) {
        self.parentState = parentState
        self.hasHistory = hasHistory
        self.childNodes = childNodes
        self.innerEdges = innerEdges
    }
}

public struct GraphJSON: Sendable, Codable {
    public let machine: String
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]
    /// Swimlane regions from `@parallel` blocks.  Empty when none are present.
    public let regions: [RegionGraph]
    /// Compound (nested) state containers.  Empty when none are present.
    public let compounds: [CompoundGraph]

    public init(
        machine: String,
        nodes: [GraphNode],
        edges: [GraphEdge],
        regions: [RegionGraph] = [],
        compounds: [CompoundGraph] = []
    ) {
        self.machine = machine
        self.nodes = nodes
        self.edges = edges
        self.regions = regions
        self.compounds = compounds
    }

    public static func from(_ file: UrkelFile) -> GraphJSON {
        // Outer nodes: top-level simple states + compound state containers.
        // Compound children are rendered inside their container, not as top-level nodes.
        let nodes: [GraphNode] = file.states.map { state in
            switch state {
            case .simple(let s):
                return GraphNode(id: s.name, label: s.name, kind: s.kind.rawValue)
            case .compound(let c):
                return GraphNode(id: c.name, label: c.name, kind: "state")
            }
        }

        let allStateNames = nodes.map(\.id)
        var edges: [GraphEdge] = []
        var edgeIdx = 0

        // Regular transitions
        for t in file.transitionStmts {
            let dest = t.destination?.name  // nil = internal self-loop

            let sources: [String]
            switch t.source {
            case .state(let r): sources = [r.name]
            case .wildcard:     sources = allStateNames  // expand * to every state
            }

            let event: String
            switch t.event {
            case .event(let e):  event = e.name
            case .timer(let tm): event = "after(\(Int(tm.duration.value))\(tm.duration.unit.rawValue))"
            case .always:        event = "always"
            }

            let guardStr: String?
            switch t.guard {
            case .named(let n):   guardStr = n
            case .negated(let n): guardStr = "!\(n)"
            case .else:           guardStr = "else"
            case nil:             guardStr = nil
            }

            for src in sources {
                let target = dest ?? src  // self-loop when no destination
                edges.append(GraphEdge(
                    id: "e\(edgeIdx)",
                    source: src,
                    target: target,
                    label: event,
                    guardLabel: guardStr
                ))
                edgeIdx += 1
            }
        }

        // Reactive @on transitions
        for r in file.reactiveStmts {
            // Source is the parallel state name or machine name
            let src: String
            switch r.source.target {
            case .machine(let m):              src = m
            case .region(parallel: let p, _):  src = p
            }

            // Event label: "@on MachineName" or "@on Parallel.Region"
            let eventLabel: String
            switch r.source.target {
            case .machine(let m):                       eventLabel = "@on \(m)"
            case .region(parallel: let p, region: let rg): eventLabel = "@on \(p).\(rg)"
            }

            let target: String
            if let dest = r.destination {
                target = dest.name
            } else if let own = r.ownState {
                target = own  // in-place: self-loop on ownState
            } else {
                target = src  // in-place with no ownState: self-loop on src
            }

            // Use ownState as source when given (more precise than the parallel state)
            let actualSrc = r.ownState ?? src

            edges.append(GraphEdge(
                id: "e\(edgeIdx)",
                source: actualSrc,
                target: target,
                label: eventLabel
            ))
            edgeIdx += 1
        }

        // Build RegionGraphs from @parallel blocks
        var regions: [RegionGraph] = []
        for parallel in file.parallels {
            for region in parallel.regions {
                let regionNodes: [GraphNode] = region.states.map { stateDecl in
                    switch stateDecl {
                    case .simple(let s):
                        return GraphNode(id: s.name, label: s.name, kind: s.kind.rawValue)
                    case .compound(let c):
                        return GraphNode(id: c.name, label: c.name, kind: "state")
                    }
                }
                let regionStateNames = regionNodes.map(\.id)
                var regionEdges: [GraphEdge] = []
                for t in region.transitions {
                    let dest = t.destination?.name
                    let sources: [String]
                    switch t.source {
                    case .state(let r): sources = [r.name]
                    case .wildcard:     sources = regionStateNames
                    }
                    let event: String
                    switch t.event {
                    case .event(let e):  event = e.name
                    case .timer(let tm): event = "after(\(Int(tm.duration.value))\(tm.duration.unit.rawValue))"
                    case .always:        event = "always"
                    }
                    let guardStr: String?
                    switch t.guard {
                    case .named(let n):   guardStr = n
                    case .negated(let n): guardStr = "!\(n)"
                    case .else:           guardStr = "else"
                    case nil:             guardStr = nil
                    }
                    for src in sources {
                        regionEdges.append(GraphEdge(
                            id: "r\(edgeIdx)",
                            source: src,
                            target: dest ?? src,
                            label: event,
                            guardLabel: guardStr
                        ))
                        edgeIdx += 1
                    }
                }
                regions.append(RegionGraph(
                    parallelState: parallel.name,
                    regionName: region.name,
                    nodes: regionNodes,
                    edges: regionEdges
                ))
            }
        }

        // Build CompoundGraphs from compound states
        var compounds: [CompoundGraph] = []
        for state in file.states {
            guard case .compound(let c) = state else { continue }
            let childNodes = c.children.map { child in
                GraphNode(id: child.name, label: child.name, kind: child.kind.rawValue)
            }
            let childStateNames = childNodes.map(\.id)
            var innerEdges: [GraphEdge] = []
            for t in c.innerTransitions {
                let dest = t.destination?.name
                let sources: [String]
                switch t.source {
                case .state(let r): sources = [r.name]
                case .wildcard:     sources = childStateNames
                }
                let event: String
                switch t.event {
                case .event(let e):  event = e.name
                case .timer(let tm): event = "after(\(Int(tm.duration.value))\(tm.duration.unit.rawValue))"
                case .always:        event = "always"
                }
                let guardStr: String?
                switch t.guard {
                case .named(let n):   guardStr = n
                case .negated(let n): guardStr = "!\(n)"
                case .else:           guardStr = "else"
                case nil:             guardStr = nil
                }
                for src in sources {
                    innerEdges.append(GraphEdge(
                        id: "c\(edgeIdx)",
                        source: src,
                        target: dest ?? src,
                        label: event,
                        guardLabel: guardStr
                    ))
                    edgeIdx += 1
                }
            }
            compounds.append(CompoundGraph(
                parentState: c.name,
                hasHistory: c.history != nil,
                childNodes: childNodes,
                innerEdges: innerEdges
            ))
        }

        // Ensure every state referenced in edges has a node (guards against parser gaps)
        var nodeSet = Set(nodes.map(\.id))
        var extraNodes: [GraphNode] = []
        for edge in edges {
            for id in [edge.source, edge.target] where !nodeSet.contains(id) && id != "*" {
                extraNodes.append(GraphNode(id: id, label: id, kind: "state"))
                nodeSet.insert(id)
            }
        }
        let allNodes = nodes + extraNodes

        return GraphJSON(machine: file.machineName, nodes: allNodes, edges: edges, regions: regions, compounds: compounds)
    }
}

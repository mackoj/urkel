import Foundation
import UrkelAST

public struct GraphNode: Sendable, Codable {
    public let id: String
    public let label: String
    /// `"init"`, `"state"`, or `"final"`
    public let kind: String
    /// Parameters carried by this state (e.g. `userId: String, token: AuthToken`).
    public let params: String?
    /// Actions that fire when entering this state (`@entry`).
    public let entryActions: [String]
    /// Actions that fire when exiting this state (`@exit`).
    public let exitActions: [String]

    public init(id: String, label: String, kind: String,
                params: String? = nil,
                entryActions: [String] = [], exitActions: [String] = []) {
        self.id = id
        self.label = label
        self.kind = kind
        self.params = params
        self.entryActions = entryActions
        self.exitActions = exitActions
    }
}

public struct GraphEdge: Sendable, Codable {
    public let id: String
    public let source: String
    public let target: String
    public let label: String
    public let guardLabel: String?
    /// Visual/semantic kind.
    /// - `"normal"`:   standard `->` transition
    /// - `"internal"`: `-*>` with action (in-place, no lifecycle)
    /// - `"output"`:   `-*>` without action (output event stream)
    /// - `"timer"`:    `after(Ns)` timer
    /// - `"reactive"`: `@on` sub-machine/region reaction
    /// - `"always"`:   automatic `always` transition
    public let edgeKind: String
    /// `/action` label if present.
    public let action: String?
    /// `=>` fork target if present (e.g. `"TokenRefresher.init"`).
    public let fork: String?

    public init(id: String, source: String, target: String, label: String,
                guardLabel: String? = nil, edgeKind: String = "normal",
                action: String? = nil, fork: String? = nil) {
        self.id = id
        self.source = source
        self.target = target
        self.label = label
        self.guardLabel = guardLabel
        self.edgeKind = edgeKind
        self.action = action
        self.fork = fork
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
        // ── Entry/Exit hooks per state ────────────────────────────────────────
        var entryMap: [String: [String]] = [:]
        var exitMap:  [String: [String]] = [:]
        for hook in file.entryExitHooks {
            let s = hook.state.name
            switch hook.hook {
            case .entry: entryMap[s, default: []].append(contentsOf: hook.actions)
            case .exit:  exitMap[s,  default: []].append(contentsOf: hook.actions)
            }
        }

        // ── Qualified name → child node ID (for "Compound.Child" dot notation) ─
        var qualifiedToChild: [String: String] = [:]
        // Also: child → parentCompound for sim hierarchy
        var childToParent: [String: String] = [:]
        for case .compound(let c) in file.states {
            for child in c.children {
                qualifiedToChild["\(c.name).\(child.name)"] = child.name
                childToParent[child.name] = c.name
            }
        }
        func resolveState(_ name: String) -> String {
            qualifiedToChild[name] ?? name
        }

        // ── Outer nodes ────────────────────────────────────────────────────────
        // Compound children are rendered inside their container, not as top-level nodes.
        let nodes: [GraphNode] = file.states.map { state in
            switch state {
            case .simple(let s):
                let paramStr = s.params.isEmpty ? nil
                    : s.params.map { "\($0.label): \($0.typeExpr)" }.joined(separator: ", ")
                return GraphNode(id: s.name, label: s.name, kind: s.kind.rawValue,
                                 params: paramStr,
                                 entryActions: entryMap[s.name] ?? [],
                                 exitActions:  exitMap[s.name] ?? [])
            case .compound(let c):
                return GraphNode(id: c.name, label: c.name, kind: "state",
                                 entryActions: entryMap[c.name] ?? [],
                                 exitActions:  exitMap[c.name] ?? [])
            }
        }

        // Non-final state IDs (for * wildcard expansion — finals never accept events)
        let finalNames = Set(nodes.filter { $0.kind == "final" }.map(\.id))
        let nonFinalNames = nodes.filter { $0.kind != "final" }.map(\.id)

        var edges: [GraphEdge] = []
        var edgeIdx = 0

        // Regular transitions
        for t in file.transitionStmts {
            let rawDest = t.destination?.name
            let dest = rawDest.map { resolveState($0) }

            // Determine source state(s)
            let rawSources: [String]
            switch t.source {
            case .state(let r): rawSources = [r.name]
            // * expands to non-final states only (per CONSTRUCTS.md spec)
            case .wildcard:     rawSources = nonFinalNames
            }
            let sources = rawSources.map { resolveState($0) }

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

            // Edge kind
            let kind: String
            switch t.event {
            case .always:  kind = "always"
            case .timer:   kind = "timer"
            case .event:
                if t.arrow == .internal {
                    kind = t.isOutputEvent ? "output" : "internal"
                } else {
                    kind = "normal"
                }
            }

            let actionStr = t.action.map { $0.actions.joined(separator: ", ") }
            let forkStr   = t.fork.map { $0.machine }

            // Machine-level output events use the machine name as source.
            // Skip creating edges that would orphan a ghost "MachineName" node.
            let isMachineLevelOutput = (kind == "output") && (rawSources.first == file.machineName)
            if isMachineLevelOutput { continue }

            for src in sources {
                let target = dest ?? src  // self-loop when no destination
                edges.append(GraphEdge(
                    id: "e\(edgeIdx)",
                    source: src,
                    target: target,
                    label: event,
                    guardLabel: guardStr,
                    edgeKind: kind,
                    action: actionStr,
                    fork: forkStr
                ))
                edgeIdx += 1
            }
        }

        // Reactive @on transitions
        for r in file.reactiveStmts {
            // Build a descriptive event label from the @on source
            let statePart: String
            switch r.source.state {
            case .named(let n): statePart = n
            case .`init`:       statePart = "init"
            case .final:        statePart = "final"
            case .any:          statePart = "*"
            }

            let eventLabel: String
            let src: String
            switch r.source.target {
            case .machine(let m):
                eventLabel = "@on \(m)::\(statePart)"
                src = m
            case .region(parallel: let p, region: let rg):
                eventLabel = "@on \(p).\(rg)::\(statePart)"
                src = p
            }

            let target: String
            if let dest = r.destination {
                target = resolveState(dest.name)
            } else if let own = r.ownState {
                target = resolveState(own)
            } else {
                target = resolveState(src)
            }

            let actualSrc = r.ownState.map { resolveState($0) } ?? resolveState(src)
            let actionStr = r.action.map { $0.actions.joined(separator: ", ") }

            edges.append(GraphEdge(
                id: "e\(edgeIdx)",
                source: actualSrc,
                target: target,
                label: eventLabel,
                edgeKind: "reactive",
                action: actionStr
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
                let regionFinalNames = Set(regionNodes.filter { $0.kind == "final" }.map(\.id))
                let regionNonFinalNames = regionNodes.filter { $0.kind != "final" }.map(\.id)
                var regionEdges: [GraphEdge] = []
                for t in region.transitions {
                    let dest = t.destination?.name
                    let sources: [String]
                    switch t.source {
                    case .state(let r): sources = [r.name]
                    case .wildcard:     sources = regionNonFinalNames
                    }
                    let event: String
                    let ek: String
                    switch t.event {
                    case .event(let e):  event = e.name; ek = t.arrow == .internal ? (t.isOutputEvent ? "output" : "internal") : "normal"
                    case .timer(let tm): event = "after(\(Int(tm.duration.value))\(tm.duration.unit.rawValue))"; ek = "timer"
                    case .always:        event = "always"; ek = "always"
                    }
                    let guardStr: String?
                    switch t.guard {
                    case .named(let n):   guardStr = n
                    case .negated(let n): guardStr = "!\(n)"
                    case .else:           guardStr = "else"
                    case nil:             guardStr = nil
                    }
                    let actionStr = t.action.map { $0.actions.joined(separator: ", ") }
                    for src in sources {
                        regionEdges.append(GraphEdge(
                            id: "r\(edgeIdx)",
                            source: src,
                            target: dest ?? src,
                            label: event,
                            guardLabel: guardStr,
                            edgeKind: ek,
                            action: actionStr
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
                let paramStr = child.params.isEmpty ? nil
                    : child.params.map { "\($0.label): \($0.typeExpr)" }.joined(separator: ", ")
                return GraphNode(id: child.name, label: child.name, kind: child.kind.rawValue,
                                 params: paramStr,
                                 entryActions: entryMap["\(c.name).\(child.name)"] ?? entryMap[child.name] ?? [],
                                 exitActions:  exitMap["\(c.name).\(child.name)"] ?? exitMap[child.name] ?? [])
            }
            let childFinalNames = Set(childNodes.filter { $0.kind == "final" }.map(\.id))
            let childNonFinalNames = childNodes.filter { $0.kind != "final" }.map(\.id)
            var innerEdges: [GraphEdge] = []
            for t in c.innerTransitions {
                let dest = t.destination?.name
                let sources: [String]
                switch t.source {
                case .state(let r): sources = [r.name]
                case .wildcard:     sources = childNonFinalNames
                }
                let event: String
                let ek: String
                switch t.event {
                case .event(let e):  event = e.name; ek = t.arrow == .internal ? (t.isOutputEvent ? "output" : "internal") : "normal"
                case .timer(let tm): event = "after(\(Int(tm.duration.value))\(tm.duration.unit.rawValue))"; ek = "timer"
                case .always:        event = "always"; ek = "always"
                }
                let guardStr: String?
                switch t.guard {
                case .named(let n):   guardStr = n
                case .negated(let n): guardStr = "!\(n)"
                case .else:           guardStr = "else"
                case nil:             guardStr = nil
                }
                let actionStr = t.action.map { $0.actions.joined(separator: ", ") }
                for src in sources {
                    innerEdges.append(GraphEdge(
                        id: "c\(edgeIdx)",
                        source: src,
                        target: dest ?? src,
                        label: event,
                        guardLabel: guardStr,
                        edgeKind: ek,
                        action: actionStr
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

        // Collect all valid node IDs including children in containers
        var knownIds = Set(nodes.map(\.id))
        regions.forEach { r in r.nodes.forEach { knownIds.insert($0.id) } }
        compounds.forEach { c in c.childNodes.forEach { knownIds.insert($0.id) } }
        // Also add the machine name itself so it never becomes a ghost node
        knownIds.insert(file.machineName)
        // Qualified compound-child names are resolved — don't create ghost nodes for them
        for key in qualifiedToChild.keys { knownIds.insert(key) }

        // Ensure every state referenced in edges has a node (guards against parser gaps)
        var nodeSet = Set(nodes.map(\.id))
        var extraNodes: [GraphNode] = []
        for edge in edges {
            for id in [edge.source, edge.target] where !nodeSet.contains(id) && !knownIds.contains(id) && id != "*" {
                extraNodes.append(GraphNode(id: id, label: id, kind: "state"))
                nodeSet.insert(id)
            }
        }
        let allNodes = nodes + extraNodes

        return GraphJSON(machine: file.machineName, nodes: allNodes, edges: edges, regions: regions, compounds: compounds)
    }
}

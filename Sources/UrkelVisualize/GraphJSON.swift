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

public struct GraphJSON: Sendable, Codable {
    public let machine: String
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]

    public static func from(_ file: UrkelFile) -> GraphJSON {
        let nodes: [GraphNode] = file.simpleStates.map { state in
            GraphNode(id: state.name, label: state.name, kind: state.kind.rawValue)
        }

        let allStateNames = file.simpleStates.map(\.name)
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

        return GraphJSON(machine: file.machineName, nodes: nodes, edges: edges)
    }
}

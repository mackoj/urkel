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

        let edges: [GraphEdge] = file.transitionStmts.enumerated().compactMap { idx, t in
            guard let dest = t.destination else { return nil }
            let from: String
            switch t.source {
            case .state(let r): from = r.name
            case .wildcard:     from = "*"
            }
            let event: String
            switch t.event {
            case .event(let e): event = e.name
            case .timer(let tm): event = "after(\(tm.duration.value)\(tm.duration.unit.rawValue))"
            case .always: event = "always"
            }
            let guardStr: String?
            switch t.guard {
            case .named(let n):   guardStr = n
            case .negated(let n): guardStr = "!\(n)"
            case .else:           guardStr = "else"
            case nil:             guardStr = nil
            }
            return GraphEdge(id: "e\(idx)", source: from, target: dest.name, label: event, guardLabel: guardStr)
        }

        return GraphJSON(machine: file.machineName, nodes: nodes, edges: edges)
    }
}

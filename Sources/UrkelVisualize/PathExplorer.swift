import Foundation
import UrkelAST

public struct MachineStep: Sendable, Codable {
    public let from: String
    public let event: String
    public let to: String
    public let guardValue: String?

    public init(from: String, event: String, to: String, guardValue: String? = nil) {
        self.from = from
        self.event = event
        self.to = to
        self.guardValue = guardValue
    }
}

public struct MachinePath: Sendable, Codable {
    public let id: String
    public let steps: [MachineStep]
    public let guards: [String: Bool]

    public init(id: String, steps: [MachineStep], guards: [String: Bool] = [:]) {
        self.id = id
        self.steps = steps
        self.guards = guards
    }
}

/// Enumerates all paths from `init` to `final` states using BFS/DFS.
public struct PathExplorer {
    public init() {}

    public func paths(in file: UrkelFile, maxPaths: Int = 100) -> [MachinePath] {
        guard let initState = file.initState else { return [] }

        let finalNames = Set(file.finalStates.map(\.name))
        let transitions = file.transitionStmts

        // Build adjacency: from → [(event, to, guard)]
        var adj: [String: [(event: String, to: String, guard: String?)]] = [:]

        // Regular transitions
        for t in transitions {
            let from: String
            switch t.source {
            case .state(let r): from = r.name
            case .wildcard: from = "*"
            }
            guard let dest = t.destination else { continue }
            let eventName: String
            switch t.event {
            case .event(let e): eventName = e.name
            case .timer(_):     eventName = "after"
            case .always:       eventName = "always"
            }
            let guardStr: String?
            switch t.guard {
            case .named(let n):   guardStr = n
            case .negated(let n): guardStr = "!\(n)"
            case .else:           guardStr = "else"
            case nil:             guardStr = nil
            }
            adj[from, default: []].append((event: eventName, to: dest.name, guard: guardStr))
        }

        // Reactive @on transitions — treated as edges from the named parallel/machine state
        // e.g. @on Processing::done -> Done  means Processing --[@on.Processing]--> Done
        for r in file.reactiveStmts {
            guard let dest = r.destination else { continue }
            let from: String
            let eventName: String
            switch r.source.target {
            case .machine(let m):
                from = m
                eventName = "@on.\(m)"
            case .region(parallel: let p, region: let rg):
                from = p
                eventName = "@on.\(p).\(rg)"
            }
            adj[from, default: []].append((event: eventName, to: dest.name, guard: nil))
        }

        // Expand wildcard edges
        let allStates = file.simpleStates.map(\.name)
        if let wildcardEdges = adj["*"] {
            for state in allStates {
                adj[state, default: []].append(contentsOf: wildcardEdges)
            }
        }

        var found: [MachinePath] = []
        var stack: [(state: String, path: [MachineStep], visited: Set<String>)] = [
            (state: initState.name, path: [], visited: [initState.name])
        ]

        while !stack.isEmpty && found.count < maxPaths {
            let (state, path, visited) = stack.removeLast()

            if finalNames.contains(state) && !path.isEmpty {
                let id = "path-\(found.count + 1)"
                found.append(MachinePath(id: id, steps: path))
                continue
            }

            for edge in adj[state] ?? [] {
                if !visited.contains(edge.to) || finalNames.contains(edge.to) {
                    let step = MachineStep(from: state, event: edge.event, to: edge.to, guardValue: edge.guard)
                    var newVisited = visited
                    newVisited.insert(edge.to)
                    stack.append((state: edge.to, path: path + [step], visited: newVisited))
                }
            }
        }

        return found
    }
}

import Foundation
import UrkelAST

/// Renders a `UrkelFile` to Mermaid.js `stateDiagram-v2` format.
public struct MermaidRenderer {
    public init() {}

    public func render(_ file: UrkelFile) -> String {
        var lines: [String] = ["stateDiagram-v2"]

        for state in file.simpleStates {
            switch state.kind {
            case .`init`:
                lines.append("    [*] --> \(state.name)")
            case .final:
                lines.append("    \(state.name) --> [*]")
            case .state:
                break
            }
        }

        for t in file.transitionStmts {
            let from: String
            switch t.source {
            case .state(let r): from = r.name
            case .wildcard:     from = "[*]"
            }
            let to = t.destination?.name ?? "[*]"
            let eventName: String
            switch t.event {
            case .event(let e): eventName = e.name
            case .timer(let tm):
                let v = tm.duration.value
                let vStr = v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
                eventName = "after(\(vStr)\(tm.duration.unit.rawValue))"
            case .always: eventName = "always"
            }
            let label = t.guard != nil ? "\(eventName) [guard]" : eventName
            lines.append("    \(from) --> \(to) : \(label)")
        }

        return lines.joined(separator: "\n")
    }
}

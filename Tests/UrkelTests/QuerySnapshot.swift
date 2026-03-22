import InlineSnapshotTesting
import SnapshotTesting
@testable import Urkel

extension Snapshotting where Value == MachineAST {
    static var urkelSummary: Snapshotting<Value, String> {
        SimplySnapshotting.lines.pullback { ast in
            let imports = ast.imports.joined(separator: ", ")
            let composed = ast.composedMachines.joined(separator: ", ")
            let stateRows = ast.states.map { state -> String in
                let kind: String
                switch state.kind {
                case .initial: kind = "init"
                case .normal: kind = "state"
                case .terminal: kind = "final"
                }
                return "  \(kind) \(state.name)"
            }.joined(separator: "\n")

            let transitionRows = ast.transitions.map { transition -> String in
                let payload = transition.parameters
                    .map { "\($0.name): \($0.type)" }
                    .joined(separator: ", ")
                let eventDecl = payload.isEmpty ? transition.event : "\(transition.event)(\(payload))"
                let fork = transition.spawnedMachine.map { " => \($0).init" } ?? ""
                return "  \(transition.from) -> \(eventDecl) -> \(transition.to)\(fork)"
            }.joined(separator: "\n")

            let factoryDecl: String
            if let factory = ast.factory {
                let params = factory.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                factoryDecl = "@factory \(factory.name)(\(params))"
            } else {
                factoryDecl = "@factory <none>"
            }

            return """
            machine \(ast.machineName)\(ast.contextType.map { "<\($0)>" } ?? "")
            imports: \(imports)
            compose: \(composed)
            \(factoryDecl)
            @states
            \(stateRows)
            @transitions
            \(transitionRows)
            """
        }
    }
}

func assertMachine(
    _ ast: @autoclosure () throws -> MachineAST,
    matches expected: (() -> String)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    function: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) rethrows {
    assertInlineSnapshot(
        of: try ast(),
        as: .urkelSummary,
        matches: expected,
        fileID: fileID,
        file: filePath,
        function: function,
        line: line,
        column: column
    )
}

func assertSwiftEmission(
    _ emitted: @autoclosure () throws -> String,
    matches expected: (() -> String)? = nil,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    function: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) rethrows {
    assertInlineSnapshot(
        of: try emitted(),
        as: .lines,
        matches: expected,
        fileID: fileID,
        file: filePath,
        function: function,
        line: line,
        column: column
    )
}

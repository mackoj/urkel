import Foundation

public enum UrkelValidationError: Error, Equatable, LocalizedError, Sendable {
    case missingInitialState
    case multipleInitialStates
    case unresolvedStateReference(stateName: String)
    case unresolvedComposedMachine(machineName: String)
    case duplicateState(stateName: String)
    case duplicateTransition(from: String, event: String, to: String)
    case unreachableState(stateName: String)
    case terminalStateHasOutgoingTransitions(stateName: String)

    public var errorDescription: String? {
        switch self {
        case .missingInitialState:
            return "Machine is missing exactly one initial state."
        case .multipleInitialStates:
            return "Machine has multiple initial states."
        case .unresolvedStateReference(let stateName):
            return "Unresolved state reference: \(stateName)"
        case .unresolvedComposedMachine(let machineName):
            return "Unresolved composed machine: \(machineName)"
        case .duplicateState(let stateName):
            return "Duplicate state declaration: \(stateName)"
        case .duplicateTransition(let from, let event, let to):
            return "Duplicate transition declaration: \(from) -> \(event) -> \(to)"
        case .unreachableState(let stateName):
            return "Unreachable state: \(stateName)"
        case .terminalStateHasOutgoingTransitions(let stateName):
            return "Terminal state '\(stateName)' cannot have outgoing transitions when strict terminal semantics are enabled."
        }
    }
}

public struct UrkelValidator {
    public struct Options: Equatable, Sendable {
        public var strictTerminalStateSemantics: Bool

        public init(strictTerminalStateSemantics: Bool = false) {
            self.strictTerminalStateSemantics = strictTerminalStateSemantics
        }
    }

    public init() {}

    public static func validate(_ ast: MachineAST, options: Options = .init()) throws {
        try checkInitialState(in: ast)
        let initialStateName = try checkStateReferences(in: ast)
        try checkComposedMachineReferences(in: ast)
        try checkDuplicateStates(in: ast)
        try checkDuplicateTransitions(in: ast)
        try checkUnreachableStates(in: ast, initialStateName: initialStateName)

        if options.strictTerminalStateSemantics {
            try checkTerminalStateExits(in: ast)
        }
    }

    private static func checkInitialState(in ast: MachineAST) throws {
        let initStates = ast.states.filter { $0.kind == .initial }
        switch initStates.count {
        case 0:
            throw UrkelValidationError.missingInitialState
        case 1:
            return
        default:
            throw UrkelValidationError.multipleInitialStates
        }
    }

    @discardableResult
    private static func checkStateReferences(in ast: MachineAST) throws -> String {
        let knownStates = Set(ast.states.map(\.name))
        let initialStateName = ast.states.first(where: { $0.kind == .initial })?.name ?? ""
        for transition in ast.transitions {
            if !knownStates.contains(transition.from) {
                throw UrkelValidationError.unresolvedStateReference(stateName: transition.from)
            }
            if !knownStates.contains(transition.to) {
                throw UrkelValidationError.unresolvedStateReference(stateName: transition.to)
            }
        }
        return initialStateName
    }

    private static func checkComposedMachineReferences(in ast: MachineAST) throws {
        let declared = Set(ast.composedMachines)
        for transition in ast.transitions {
            guard let spawned = transition.spawnedMachine else { continue }
            if !declared.contains(spawned) {
                throw UrkelValidationError.unresolvedComposedMachine(machineName: spawned)
            }
        }
    }

    private static func checkDuplicateStates(in ast: MachineAST) throws {
        var seen = Set<String>()
        for state in ast.states {
            if !seen.insert(state.name).inserted {
                throw UrkelValidationError.duplicateState(stateName: state.name)
            }
        }
    }

    private static func checkDuplicateTransitions(in ast: MachineAST) throws {
        struct TransitionSignature: Hashable {
            let from: String
            let event: String
            let parameters: [String]
            let to: String
        }

        var seen = Set<TransitionSignature>()
        for transition in ast.transitions {
            let signature = TransitionSignature(
                from: transition.from,
                event: transition.event,
                parameters: transition.parameters.map { "\($0.name):\($0.type)" },
                to: transition.to
            )
            if !seen.insert(signature).inserted {
                throw UrkelValidationError.duplicateTransition(
                    from: transition.from,
                    event: transition.event,
                    to: transition.to
                )
            }
        }
    }

    private static func checkUnreachableStates(in ast: MachineAST, initialStateName: String) throws {
        guard !initialStateName.isEmpty else { return }

        var adjacency: [String: [String]] = [:]
        for transition in ast.transitions {
            adjacency[transition.from, default: []].append(transition.to)
        }

        var visited: Set<String> = []
        var queue: [String] = [initialStateName]
        while !queue.isEmpty {
            let state = queue.removeFirst()
            guard visited.insert(state).inserted else { continue }
            for next in adjacency[state, default: []] where !visited.contains(next) {
                queue.append(next)
            }
        }

        for state in ast.states {
            if !visited.contains(state.name) {
                throw UrkelValidationError.unreachableState(stateName: state.name)
            }
        }
    }

    private static func checkTerminalStateExits(in ast: MachineAST) throws {
        let terminalStates = Set(ast.states.filter { $0.kind == .terminal }.map(\.name))
        guard !terminalStates.isEmpty else { return }

        for transition in ast.transitions where terminalStates.contains(transition.from) {
            throw UrkelValidationError.terminalStateHasOutgoingTransitions(stateName: transition.from)
        }
    }
}

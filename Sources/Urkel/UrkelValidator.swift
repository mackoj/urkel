import Foundation

public enum UrkelValidationError: Error, Equatable, LocalizedError, Sendable {
    case missingInitialState
    case multipleInitialStates
    case unresolvedStateReference(stateName: String)
    case unresolvedComposedMachine(machineName: String)

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
        }
    }
}

public struct UrkelValidator {
    public init() {}

    public static func validate(_ ast: MachineAST) throws {
        try checkInitialState(in: ast)
        try checkStateReferences(in: ast)
        try checkComposedMachineReferences(in: ast)
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

    private static func checkStateReferences(in ast: MachineAST) throws {
        let knownStates = Set(ast.states.map(\.name))
        for transition in ast.transitions {
            if !knownStates.contains(transition.from) {
                throw UrkelValidationError.unresolvedStateReference(stateName: transition.from)
            }
            if !knownStates.contains(transition.to) {
                throw UrkelValidationError.unresolvedStateReference(stateName: transition.to)
            }
        }
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
}

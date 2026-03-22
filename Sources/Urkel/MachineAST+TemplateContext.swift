import Foundation

public extension MachineAST {
    /// Canonical template context used by template-based emitters.
    var templateContext: [String: Any] {
        templateContext(templateImportsOverride: nil)
    }

    /// Canonical template context with optional import overrides.
    func templateContext(templateImportsOverride: [String]?) -> [String: Any] {
        let statePayload = states.enumerated().map { index, state in
            [
                "name": state.name,
                "kind": state.kind.stringValue,
                "isInitial": state.kind == .initial,
                "isTerminal": state.kind == .terminal,
                "isLast": index == states.count - 1
            ] as [String: Any]
        }

        let transitionPayload = transitions.enumerated().map { transitionIndex, transition in
            [
                "from": transition.from,
                "event": transition.event,
                "to": transition.to,
                "isLast": transitionIndex == transitions.count - 1,
                "parameters": transition.parameters.enumerated().map { parameterIndex, parameter in
                    [
                        "name": parameter.name,
                        "type": parameter.type,
                        "isLast": parameterIndex == transition.parameters.count - 1
                    ] as [String: Any]
                }
            ] as [String: Any]
        }

        let factoryPayload: [String: Any]? = factory.map { factory in
            [
                "name": factory.name,
                "parameters": factory.parameters.enumerated().map { index, parameter in
                    [
                        "name": parameter.name,
                        "type": parameter.type,
                        "isLast": index == factory.parameters.count - 1
                    ] as [String: Any]
                }
            ]
        }

        let imports = templateImportsOverride
            ?? emitterOptions?.templateImports
            ?? self.imports

        return [
            "machineName": machineName,
            "contextType": contextType as Any,
            "imports": imports,
            "states": statePayload,
            "transitions": transitionPayload,
            "initialState": states.first(where: { $0.kind == .initial })?.name as Any,
            "factory": factoryPayload as Any
        ]
    }

    /// Backward-compatible alias for template context payload.
    var dictionaryRepresentation: [String: Any] {
        templateContext
    }
}

private extension MachineAST.StateNode.Kind {
    var stringValue: String {
        switch self {
        case .initial: return "initial"
        case .normal: return "normal"
        case .terminal: return "terminal"
        }
    }
}

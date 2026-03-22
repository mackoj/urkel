import Foundation

public extension MachineAST {
    /// Canonical template context used by template-based emitters.
    var templateContext: [String: Any] {
        templateContext(templateImportsOverride: nil)
    }

    /// Canonical template context with optional import overrides.
    func templateContext(templateImportsOverride: [String]?) -> [String: Any] {
        let machineTypeName = normalizedTypeName(machineName)
        let stateRows = states.enumerated().map { index, state in
            let stateTypeName = normalizedTypeName(state.name)
            return [
                "name": state.name,
                "typeName": stateTypeName,
                "variableName": lowerCamelName(stateTypeName),
                "kind": state.kind.stringValue,
                "isInitial": state.kind == .initial,
                "isTerminal": state.kind == .terminal,
                "isLast": index == states.count - 1
            ] as [String: Any]
        }

        let groupedTransitionRows = Dictionary(grouping: transitions) { transition in
            transition.from
        }

        let transitionRows = transitions.enumerated().map { transitionIndex, transition in
            let eventName = transition.event
            let eventTypeName = normalizedTypeName(eventName)
            let toStateTypeName = normalizedTypeName(transition.to)
            return [
                "from": transition.from,
                "fromTypeName": normalizedTypeName(transition.from),
                "event": transition.event,
                "eventTypeName": eventTypeName,
                "to": transition.to,
                "toTypeName": toStateTypeName,
                "spawnedMachine": transition.spawnedMachine as Any,
                "spawnedMachineTypeName": transition.spawnedMachine.map(normalizedTypeName) as Any,
                "isLast": transitionIndex == transitions.count - 1,
                "parameters": transition.parameters.enumerated().map { parameterIndex, parameter in
                    [
                        "name": parameter.name,
                        "nameTypeName": normalizedTypeName(parameter.name),
                        "type": parameter.type,
                        "typeTypeName": normalizedTypeName(parameter.type),
                        "isLast": parameterIndex == transition.parameters.count - 1
                    ] as [String: Any]
                }
            ] as [String: Any]
        }

        let groupedTransitionPayload = groupedTransitionRows.keys.sorted().map { sourceState in
            let grouped = groupedTransitionRows[sourceState] ?? []
            return [
                "sourceState": sourceState,
                "sourceStateTypeName": normalizedTypeName(sourceState),
                "transitions": grouped.enumerated().map { index, transition in
                    [
                        "event": transition.event,
                        "eventTypeName": normalizedTypeName(transition.event),
                        "to": transition.to,
                        "toTypeName": normalizedTypeName(transition.to),
                        "spawnedMachine": transition.spawnedMachine as Any,
                        "spawnedMachineTypeName": transition.spawnedMachine.map(normalizedTypeName) as Any,
                        "parameters": transition.parameters.enumerated().map { parameterIndex, parameter in
                            [
                                "name": parameter.name,
                                "nameTypeName": normalizedTypeName(parameter.name),
                                "type": parameter.type,
                                "typeTypeName": normalizedTypeName(parameter.type),
                                "isLast": parameterIndex == transition.parameters.count - 1
                            ] as [String: Any]
                        },
                        "isLast": index == grouped.count - 1
                    ] as [String: Any]
                },
                "isLast": sourceState == groupedTransitionRows.keys.sorted().last
            ] as [String: Any]
        }

        let factoryPayload: [String: Any]? = factory.map { factory in
            [
                "name": factory.name,
                "nameTypeName": normalizedTypeName(factory.name),
                "parameters": factory.parameters.enumerated().map { index, parameter in
                    [
                        "name": parameter.name,
                        "nameTypeName": normalizedTypeName(parameter.name),
                        "type": parameter.type,
                        "typeTypeName": normalizedTypeName(parameter.type),
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
            "machineTypeName": machineTypeName,
            "machineVariableName": lowerCamelName(machineTypeName),
            "contextType": contextType as Any,
            "imports": imports,
            "states": stateRows,
            "transitions": transitionRows,
            "groupedTransitions": groupedTransitionPayload,
            "composedMachines": composedMachines.enumerated().map { index, machine in
                [
                    "name": machine,
                    "typeName": normalizedTypeName(machine),
                    "variableName": lowerCamelName(normalizedTypeName(machine)),
                    "isLast": index == composedMachines.count - 1
                ] as [String: Any]
            },
            "initialState": states.first(where: { $0.kind == .initial })?.name as Any,
            "initialStateTypeName": states.first(where: { $0.kind == .initial }).map { normalizedTypeName($0.name) } as Any,
            "factory": factoryPayload as Any
        ]
    }

    /// Backward-compatible alias for template context payload.
    var dictionaryRepresentation: [String: Any] {
        templateContext
    }

    private func normalizedTypeName(_ raw: String) -> String {
        let separators = CharacterSet.alphanumerics.inverted
        let parts = raw
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return raw }
        return parts
            .map { part in
                let head = part.prefix(1).uppercased()
                let tail = part.dropFirst()
                return head + tail
            }
            .joined()
    }

    private func lowerCamelName(_ raw: String) -> String {
        guard let first = raw.first else { return raw }
        return String(first).lowercased() + raw.dropFirst()
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

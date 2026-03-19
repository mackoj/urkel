import Foundation

public struct UrkelEmitter {
    public init() {}

    public func emit(ast: MachineAST) -> String {
        let names = Names(from: ast.machineName)
        return [
            emitImports(for: ast),
            emitStates(for: ast),
            emitObserver(for: ast, names: names),
            emitExtensions(for: ast, names: names),
            emitCombinedStateWrapper(for: ast, names: names),
            emitClient(for: ast, names: names)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    private func emitImports(for ast: MachineAST) -> String {
        var lines: [String] = []
        let allImports = ast.imports.isEmpty ? ["Foundation"] : ast.imports
        for item in allImports where !lines.contains("import \(item)") {
            lines.append("import \(item)")
        }
        if !lines.contains("import Dependencies") {
            lines.append("import Dependencies")
        }
        return lines.joined(separator: "\n")
    }

    private func emitStates(for ast: MachineAST) -> String {
        ast.states.map { "public enum \($0.name) {}" }.joined(separator: "\n")
    }

    private func emitObserver(for ast: MachineAST, names: Names) -> String {
        let contextType = ast.contextType ?? "Any"

        let uniqueTransitions = ast.transitions.reduce(into: [MachineAST.TransitionNode]()) { partial, transition in
            if !partial.contains(where: { $0.event == transition.event }) {
                partial.append(transition)
            }
        }

        let closureProps = uniqueTransitions.map { transition in
            let eventParamTypes = transition.parameters.map(\.type)
            let closureInput = ([contextType] + eventParamTypes).joined(separator: ", ")
            return "    private let _\(transition.event): @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: "\n")

        let initParams = uniqueTransitions.map { transition in
            let eventParamTypes = transition.parameters.map(\.type)
            let closureInput = ([contextType] + eventParamTypes).joined(separator: ", ")
            return "        _\(transition.event): @escaping @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: ",\n")

        let assignments = uniqueTransitions.map { "        self._\($0.event) = _\($0.event)" }.joined(separator: "\n")

        return """
        public struct \(names.observerTypeName)<State>: ~Copyable {
            private var internalContext: \(contextType)
        \(closureProps.isEmpty ? "" : "\n\(closureProps)")

            public init(
                internalContext: \(contextType)\(initParams.isEmpty ? "" : ",\n\(initParams)")
            ) {
                self.internalContext = internalContext
        \(assignments.isEmpty ? "" : "\n\(assignments)")
            }

            public borrowing func withInternalContext<R>(_ body: (borrowing \(contextType)) throws -> R) rethrows -> R {
                try body(self.internalContext)
            }
        }
        """
    }

    private func emitExtensions(for ast: MachineAST, names: Names) -> String {
        let grouped = Dictionary(grouping: ast.transitions, by: { $0.from })
        let orderedStates = ast.transitions.map(\.from).reduce(into: [String]()) { partial, state in
            if !partial.contains(state) {
                partial.append(state)
            }
        }

        return orderedStates.compactMap { fromState in
            guard let transitions = grouped[fromState] else { return nil }
            let methods = transitions.map { transition in
                let params = transition.parameters
                let signatureParams = params.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let callArgs = params.map { $0.name }.joined(separator: ", ")
                let observerPassThrough = ast.transitions.reduce(into: [String]()) { partial, next in
                    if !partial.contains(next.event) {
                        partial.append(next.event)
                    }
                }.map { event in "                _\(event): self._\(event)" }.joined(separator: ",\n")

                return """
                    public consuming func \(transition.event)(\(signatureParams)) async throws -> \(names.observerTypeName)<\(transition.to)> {
                        let nextContext = try await self._\(transition.event)(self.internalContext\(callArgs.isEmpty ? "" : ", \(callArgs)"))
                        return \(names.observerTypeName)<\(transition.to)>(
                            internalContext: nextContext\(observerPassThrough.isEmpty ? "" : ",\n\(observerPassThrough)")
                        )
                    }
                """
            }.joined(separator: "\n\n")

            return """
            extension \(names.observerTypeName) where State == \(fromState) {
            \(methods)
            }
            """
        }.joined(separator: "\n\n")
    }

    private func emitCombinedStateWrapper(for ast: MachineAST, names: Names) -> String {
        guard !ast.states.isEmpty else { return "" }

        let cases = ast.states
            .map { state in
                "    case \(caseName(for: state.name))(\(names.observerTypeName)<\(state.name)>)"
            }
            .joined(separator: "\n")

        let initialInit: String = {
            guard let initial = ast.states.first(where: { $0.kind == .initial }) else { return "" }
            return """

                public init(_ observer: consuming \(names.observerTypeName)<\(initial.name)>) {
                    self = .\(caseName(for: initial.name))(observer)
                }
            """
        }()

        let stateCases = ast.states.map { caseName(for: $0.name) }

        let unwraps = ast.states.map { state in
            let methodName = "with\(normalizedTypeName(state.name))"
            let stateCase = caseName(for: state.name)
            let invalidCaseBranches = stateCases
                .filter { $0 != stateCase }
                .map { """
                        case .\($0):
                            return nil
                """ }
                .joined(separator: "\n")
            let invalidBranch = invalidCaseBranches.isEmpty ? "" : "\n\(invalidCaseBranches)"
            return """
                public borrowing func \(methodName)<R>(_ body: (borrowing \(names.observerTypeName)<\(state.name)>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .\(stateCase)(observer):
                        return try body(observer)
            \(invalidBranch)
                    }
                }
            """
        }.joined(separator: "\n\n")

        var orderedSignatures: [TransitionSignature] = []
        var transitionsBySignature: [TransitionSignature: [MachineAST.TransitionNode]] = [:]
        for transition in ast.transitions {
            let signature = TransitionSignature(
                event: transition.event,
                parameters: transition.parameters.map { .init(name: $0.name, type: $0.type) }
            )
            if transitionsBySignature[signature] == nil {
                orderedSignatures.append(signature)
            }
            transitionsBySignature[signature, default: []].append(transition)
        }

        let transitionMethods = orderedSignatures.compactMap { signature -> String? in
            guard let transitions = transitionsBySignature[signature], let exemplar = transitions.first else { return nil }
            let params = exemplar.parameters
            let signatureParams = params.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
            let callArgs = params.map(\.name).joined(separator: ", ")

            let transitionByFrom = Dictionary(uniqueKeysWithValues: transitions.map { ($0.from, $0) })
            let switchCases = ast.states.map { state in
                let currentCase = caseName(for: state.name)
                if let transition = transitionByFrom[state.name] {
                    let destinationCase = caseName(for: transition.to)
                    return """
                            case let .\(currentCase)(observer):
                                let next = try await observer.\(signature.event)(\(callArgs))
                                return .\(destinationCase)(next)
                        """
                }
                return """
                        case let .\(currentCase)(observer):
                            return .\(currentCase)(observer)
                    """
            }.joined(separator: "\n")

            return """
                public consuming func \(signature.event)(\(signatureParams)) async throws -> Self {
                    switch consume self {
            \(switchCases)
                    }
                }
            """
        }.joined(separator: "\n\n")

        return """
        public enum \(names.stateWrapperTypeName): ~Copyable {
        \(cases)
        \(initialInit)
        }

        extension \(names.stateWrapperTypeName) {
        \(unwraps)
        \(transitionMethods.isEmpty ? "" : "\n\n\(transitionMethods)")
        }
        """
    }

    private func emitClient(for ast: MachineAST, names: Names) -> String {
        let factoryName = ast.factory?.name ?? "makeObserver"
        let initialState = ast.states.first(where: { $0.kind == .initial })?.name ?? "Initial"
        let parameters = ast.factory?.parameters ?? []

        let propertyFunctionType: String = {
            let paramTypes = parameters.map(\.type)
            if paramTypes.isEmpty {
                return "@Sendable () -> \(names.observerTypeName)<\(initialState)>"
            }
            return "@Sendable (\(paramTypes.joined(separator: ", "))) -> \(names.observerTypeName)<\(initialState)>"
        }()

        return """
        public struct \(names.clientTypeName): Sendable {
            public var \(factoryName): \(propertyFunctionType)

            public init(\(factoryName): @escaping \(propertyFunctionType)) {
                self.\(factoryName) = \(factoryName)
            }
        }

        extension \(names.clientTypeName): DependencyKey {
            public static let testValue = Self(
                \(factoryName): \(placeholderFactoryClosure(parameterCount: parameters.count, message: "Configure \(names.clientTypeName).testValue in tests."))
            )

            public static let previewValue = Self(
                \(factoryName): \(placeholderFactoryClosure(parameterCount: parameters.count, message: "Configure \(names.clientTypeName).previewValue in previews."))
            )

            public static let liveValue = Self(
                \(factoryName): \(placeholderFactoryClosure(parameterCount: parameters.count, message: "Configure \(names.clientTypeName).liveValue in your app target."))
            )
        }

        extension DependencyValues {
            public var \(names.dependencyKeyName): \(names.clientTypeName) {
                get { self[\(names.clientTypeName).self] }
                set { self[\(names.clientTypeName).self] = newValue }
            }
        }
        """
    }

    private func placeholderFactoryClosure(parameterCount: Int, message: String) -> String {
        let leading = String(repeating: "_", count: parameterCount)
        let arguments: String
        if parameterCount == 0 {
            arguments = ""
        } else {
            arguments = leading.map { _ in "_" }.joined(separator: ", ") + " in "
        }

        return """
{
                    \(arguments)fatalError("\(message)")
                }
"""
    }

    private func caseName(for stateName: String) -> String {
        lowerCamelName(from: stateName)
    }

    private func normalizedTypeName(_ raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)

        let parts = cleaned.isEmpty ? [raw] : cleaned
        return parts
            .flatMap(splitCompoundToken)
            .map { token in
                guard let first = token.first else { return "" }
                return String(first).uppercased() + token.dropFirst()
            }
            .joined()
    }

    private func lowerCamelName(from raw: String) -> String {
        let normalized = normalizedTypeName(raw)
        guard let first = normalized.first else { return normalized }
        return String(first).lowercased() + normalized.dropFirst()
    }

    private func splitCompoundToken(_ token: String) -> [String] {
        guard !token.isEmpty else { return [] }
        let lowercase = token.lowercased()

        if token != lowercase {
            return [token]
        }

        for suffix in compoundSuffixes where lowercase.hasSuffix(suffix) && lowercase.count > suffix.count {
            let prefix = String(lowercase.dropLast(suffix.count))
            guard prefix.count >= 2 else { continue }
            let prefixParts = splitCompoundToken(prefix)
            return prefixParts + [suffix]
        }

        return [lowercase]
    }

    private var compoundSuffixes: [String] {
        [
            "observer",
            "dependency",
            "dependencies",
            "generator",
            "runtime",
            "context",
            "factory",
            "machine",
            "client",
            "server",
            "watch",
            "state",
            "plugin",
            "parser",
            "model",
            "view"
        ]
    }

    private struct Names {
        let machineTypeName: String
        let observerTypeName: String
        let clientTypeName: String
        let stateWrapperTypeName: String
        let dependencyKeyName: String

        init(from machineName: String) {
            let machineType = UrkelEmitter().normalizedTypeName(machineName)
            self.machineTypeName = machineType
            self.observerTypeName = "\(machineType)Observer"
            self.clientTypeName = "\(machineType)Client"
            self.stateWrapperTypeName = "\(machineType)State"
            self.dependencyKeyName = UrkelEmitter().lowerCamelName(from: machineType)
        }
    }

    private struct TransitionParameterSignature: Hashable {
        let name: String
        let type: String
    }

    private struct TransitionSignature: Hashable {
        let event: String
        let parameters: [TransitionParameterSignature]
    }
}

import Foundation

public struct UrkelEmitter {
    public init() {}

    public func emit(ast: MachineAST) -> String {
        [
            emitImports(for: ast),
            emitStates(for: ast),
            emitObserver(for: ast),
            emitExtensions(for: ast),
            emitClient(for: ast)
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

    private func emitObserver(for ast: MachineAST) -> String {
        let machineName = ast.machineName
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
        public struct \(machineName)Observer<State>: ~Copyable {
            private var internalContext: \(contextType)
        \(closureProps.isEmpty ? "" : "\n\(closureProps)")

            public init(
                internalContext: \(contextType)\(initParams.isEmpty ? "" : ",\n\(initParams)")
            ) {
                self.internalContext = internalContext
        \(assignments.isEmpty ? "" : "\n\(assignments)")
            }
        }
        """
    }

    public func emitExtensions(for ast: MachineAST) -> String {
        let machineName = ast.machineName
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
                    public consuming func \(transition.event)(\(signatureParams)) async throws -> \(machineName)Observer<\(transition.to)> {
                        let nextContext = try await self._\(transition.event)(self.internalContext\(callArgs.isEmpty ? "" : ", \(callArgs)"))
                        return \(machineName)Observer<\(transition.to)>(
                            internalContext: nextContext\(observerPassThrough.isEmpty ? "" : ",\n\(observerPassThrough)")
                        )
                    }
                """
            }.joined(separator: "\n\n")

            return """
            extension \(machineName)Observer where State == \(fromState) {
            \(methods)
            }
            """
        }.joined(separator: "\n\n")
    }

    public func emitClient(for ast: MachineAST) -> String {
        let machineName = ast.machineName
        let clientName = "\(machineName)Client"
        let factoryName = ast.factory?.name ?? "makeObserver"
        let initialState = ast.states.first(where: { $0.kind == .initial })?.name ?? "Initial"
        let parameters = ast.factory?.parameters ?? []

        let propertyFunctionType: String = {
            let paramTypes = parameters.map(\.type)
            if paramTypes.isEmpty {
                return "@Sendable () -> \(machineName)Observer<\(initialState)>"
            }
            return "@Sendable (\(paramTypes.joined(separator: ", "))) -> \(machineName)Observer<\(initialState)>"
        }()

        let underscoreArgs: String = {
            guard !parameters.isEmpty else { return "" }
            return parameters.map { _ in "_" }.joined(separator: ", ")
        }()
        let closureParameters = underscoreArgs.isEmpty ? "" : "\(underscoreArgs) in "

        return """
        public struct \(clientName): Sendable {
            public var \(factoryName): \(propertyFunctionType)

            public init(\(factoryName): @escaping \(propertyFunctionType)) {
                self.\(factoryName) = \(factoryName)
            }
        }

        extension \(clientName): TestDependencyKey {
            public static let testValue = Self(
                \(factoryName): { \(closureParameters)
                    fatalError("Configure \(clientName).testValue in tests.")
                }
            )
        }

        extension DependencyValues {
            public var \(lowercaseFirst(machineName)): \(clientName) {
                get { self[\(clientName).self] }
                set { self[\(clientName).self] = newValue }
            }
        }
        """
    }

    private func lowercaseFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).lowercased() + value.dropFirst()
    }
}

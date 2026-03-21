import Foundation

/// Native Swift code emitter used for the default Urkel generation path.
public struct SwiftCodeEmitter {
    public init() {}

    public func emit(ast: MachineAST) -> String {
        let names = Names(from: ast.machineName)
        return [
            emitImports(for: ast),
            emitStates(for: ast, names: names),
            emitRuntimeContextBridge(for: ast, names: names),
            emitObserver(for: ast, names: names),
            emitRuntimeStreamHelper(for: ast, names: names),
            emitClientRuntimeBuilder(for: ast, names: names),
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

    private func emitStates(for ast: MachineAST, names: Names) -> String {
        let stateLines = ast.states
            .map { "    public enum \($0.name) {}" }
            .joined(separator: "\n")
        let runtimeContext = ast.contextType == nil
            ? """

                public struct RuntimeContext: Sendable {
                    public init() {}
                }
            """
            : ""

        return """
        // MARK: - \(names.machineTypeName) State Machine

        /// Typestate markers for the `\(names.machineTypeName)` machine.
        public enum \(names.machineNamespaceTypeName) {
        \(stateLines)\(runtimeContext)
        }
        """
    }

    private func emitRuntimeContextBridge(for ast: MachineAST, names: Names) -> String {
        let contextType = ast.contextType ?? "\(names.machineNamespaceTypeName).RuntimeContext"
        guard !ast.states.isEmpty else { return "" }

        let storageCases = ast.states
            .map { "        case \(caseName(for: $0.name))(\(contextType))" }
            .joined(separator: "\n")
        let accessors = ast.states
            .map { state in
                """
                static func \(caseName(for: state.name))(_ value: \(contextType)) -> Self {
                    .init(storage: .\(caseName(for: state.name))(value))
                }
                """
            }
            .joined(separator: "\n\n")

        return """
        // MARK: - \(names.machineTypeName) Runtime Context Bridge

        /// Internal state-aware context wrapper used by generated runtime helpers.
        struct \(names.machineTypeName)RuntimeContext: Sendable {
            enum Storage: Sendable {
        \(storageCases)
            }

            let storage: Storage

            init(storage: Storage) {
                self.storage = storage
            }

        \(accessors)
        }
        """
    }

    private func emitObserver(for ast: MachineAST, names: Names) -> String {
        let contextType = ast.contextType ?? "\(names.machineNamespaceTypeName).RuntimeContext"
        let signatures = orderedTransitionSignatures(in: ast)

        let closureProps = signatures.compactMap { signature -> String? in
            guard let exemplar = transitions(for: signature, in: ast).first else { return nil }
            let eventParamTypes = exemplar.parameters.map(\.type)
            let closureInput = ([contextType] + eventParamTypes).joined(separator: ", ")
            return "    private let \(transitionPropertyName(for: signature)): @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: "\n")

        let initParams = signatures.compactMap { signature -> String? in
            guard let exemplar = transitions(for: signature, in: ast).first else { return nil }
            let eventParamTypes = exemplar.parameters.map(\.type)
            let closureInput = ([contextType] + eventParamTypes).joined(separator: ", ")
            return "        \(transitionPropertyName(for: signature)): @escaping @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: ",\n")

        let assignments = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            let closureName = transitionPropertyName(for: signature)
            return "        self.\(closureName) = \(closureName)"
        }.joined(separator: "\n")

        return """
        // MARK: - \(names.machineTypeName) Observer

        /// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
        public struct \(names.observerTypeName)<State>: ~Copyable {
            private var internalContext: \(contextType)
        \(closureProps.isEmpty ? "" : "\n\(closureProps)")

            public init(
                internalContext: \(contextType)\(initParams.isEmpty ? "" : ",\n\(initParams)")
            ) {
                self.internalContext = internalContext
        \(assignments.isEmpty ? "" : "\n\(assignments)")
            }

            /// Access the internal context while preserving borrowing semantics.
            public borrowing func withInternalContext<R>(_ body: (borrowing \(contextType)) throws -> R) rethrows -> R {
                try body(self.internalContext)
            }
        }
        """
    }

    private func emitRuntimeStreamHelper(for ast: MachineAST, names: Names) -> String {
        guard !ast.transitions.isEmpty else { return "" }

        return """
        // MARK: - \(names.machineTypeName) Runtime Stream

        /// Generic stream lifecycle helper for event-driven runtimes generated from this machine.
        actor \(names.machineTypeName)RuntimeStream<Element: Sendable> {
            nonisolated let events: AsyncThrowingStream<Element, Error>

            private var continuation: AsyncThrowingStream<Element, Error>.Continuation?
            private var pendingEvent: Element?
            private var debounceTask: Task<Void, Never>?
            private let debounceMs: Int

            init(debounceMs: Int = 0) {
                self.debounceMs = max(0, debounceMs)

                var capturedContinuation: AsyncThrowingStream<Element, Error>.Continuation?
                self.events = AsyncThrowingStream<Element, Error> { continuation in
                    capturedContinuation = continuation
                }
                self.continuation = capturedContinuation
            }

            func emit(_ event: Element) {
                guard let continuation else { return }

                if debounceMs == 0 {
                    continuation.yield(event)
                    return
                }

                pendingEvent = event
                debounceTask?.cancel()
                debounceTask = Task { [debounceMs] in
                    try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
                    self.flushPendingEvent()
                }
            }

            func finish(throwing error: Error? = nil) {
                debounceTask?.cancel()
                debounceTask = nil
                pendingEvent = nil
                continuation?.finish(throwing: error)
                continuation = nil
            }

            private func flushPendingEvent() {
                guard let event = pendingEvent else { return }
                pendingEvent = nil
                continuation?.yield(event)
            }
        }
        """
    }

    private func emitClientRuntimeBuilder(for ast: MachineAST, names: Names) -> String {
        let contextType = ast.contextType ?? "\(names.machineNamespaceTypeName).RuntimeContext"
        let signatures = orderedTransitionSignatures(in: ast)
        guard !signatures.isEmpty else { return "" }

        let factoryName = ast.factory?.name ?? "makeObserver"
        let factoryParameters = ast.factory?.parameters ?? []
        let initialContextTypeAlias: String = {
            let paramTypes = factoryParameters.map(\.type)
            if paramTypes.isEmpty {
                return "@Sendable () -> \(contextType)"
            }
            return "@Sendable (\(paramTypes.joined(separator: ", "))) -> \(contextType)"
        }()

        let closureAliases = signatures.compactMap { signature -> String? in
            guard let exemplar = transitions(for: signature, in: ast).first else { return nil }
            let eventParamTypes = exemplar.parameters.map(\.type)
            let closureInput = ([contextType] + eventParamTypes).joined(separator: ", ")
            return "    typealias \(transitionAliasName(for: signature)) = @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: "\n")

        let properties = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            return "    let \(transitionBuilderName(for: signature)): \(transitionAliasName(for: signature))"
        }.joined(separator: "\n")

        let factoryInitArgs = factoryParameters.map(\.name).joined(separator: ", ")
        let factoryClosureParameters = factoryParameters
            .map(\.name)
            .joined(separator: ", ")
        let factoryClosureSignature: String = factoryClosureParameters.isEmpty ? "" : "\(factoryClosureParameters) in"

        let initParams = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            return "\(transitionBuilderName(for: signature)): @escaping \(transitionAliasName(for: signature))"
        }.joined(separator: ",\n        ")
        let initParamList = ([ "initialContext: @escaping InitialContextBuilder" ] + (initParams.isEmpty ? [] : [initParams]))
            .joined(separator: ",\n        ")

        let assignments = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            let builder = transitionBuilderName(for: signature)
            return "        self.\(builder) = \(builder)"
        }.joined(separator: "\n")
        let assignmentBlock = ([
            "        self.initialContext = initialContext"
        ] + (assignments.isEmpty ? [] : [assignments])).joined(separator: "\n")

        let observerArgs = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            return "\(transitionPropertyName(for: signature)): runtime.\(transitionBuilderName(for: signature))"
        }.joined(separator: ",\n                ")

        let initialState = ast.states.first(where: { $0.kind == .initial }).map(\.name) ?? "Initial"
        let initialStateType = stateTypeName(for: initialState, names: names)

        return """
        // MARK: - \(names.machineTypeName) Runtime Builder

        /// Runtime transition hooks used to construct a machine observer without editing generated code.
        struct \(names.machineTypeName)ClientRuntime {
            typealias InitialContextBuilder = \(initialContextTypeAlias)
        \(closureAliases)
            let initialContext: InitialContextBuilder
        \(properties)

            init(
                \(initParamList)
            ) {
        \(assignmentBlock)
            }
        }

        extension \(names.clientTypeName) {
            /// Builds a client factory from explicit runtime transition hooks.
            static func fromRuntime(_ runtime: \(names.machineTypeName)ClientRuntime) -> Self {
                Self(
                    \(factoryName): {\(factoryClosureSignature.isEmpty ? "" : " \(factoryClosureSignature)")
                        let context = runtime.initialContext(\(factoryInitArgs))
                        return \(names.observerTypeName)<\(initialStateType)>(
                            internalContext: context\((observerArgs.isEmpty ? "" : ",\n                \(observerArgs)"))
                        )
                    }
                )
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
            guard let stateTransitions = grouped[fromState] else { return nil }
            let methods = stateTransitions.map { transition in
                let params = transition.parameters
                let destinationType = stateTypeName(for: transition.to, names: names)
                let signatureParams = params.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let callArgs = params.map { $0.name }.joined(separator: ", ")
                let observerPassThrough = orderedTransitionSignatures(in: ast).compactMap { signature -> String? in
                    guard self.transitions(for: signature, in: ast).first != nil else { return nil }
                    let closureName = transitionPropertyName(for: signature)
                    return "                \(closureName): self.\(closureName)"
                }.joined(separator: ",\n")

                return """
                    /// Handles the `\(transition.event)` transition from \(fromState) to \(transition.to).
                    public consuming func \(transition.event)(\(signatureParams)) async throws -> \(names.observerTypeName)<\(destinationType)> {
                        let nextContext = try await self.\(transitionPropertyName(for: transition))(self.internalContext\(callArgs.isEmpty ? "" : ", \(callArgs)"))
                        return \(names.observerTypeName)<\(destinationType)>(
                            internalContext: nextContext\(observerPassThrough.isEmpty ? "" : ",\n\(observerPassThrough)")
                        )
                    }
                """
            }.joined(separator: "\n\n")

            let fromStateType = stateTypeName(for: fromState, names: names)
            return """
            // MARK: - \(names.machineTypeName).\(fromState) Transitions

            extension \(names.observerTypeName) where State == \(fromStateType) {
            \(methods)
            }
            """
        }.joined(separator: "\n\n")
    }

    private func emitCombinedStateWrapper(for ast: MachineAST, names: Names) -> String {
        guard !ast.states.isEmpty else { return "" }

        let cases = ast.states
            .map { state in
                let stateType = stateTypeName(for: state.name, names: names)
                return "    case \(caseName(for: state.name))(\(names.observerTypeName)<\(stateType)>)"
            }
            .joined(separator: "\n")

        let initialInit: String = {
            guard let initial = ast.states.first(where: { $0.kind == .initial }) else { return "" }
            let initialType = stateTypeName(for: initial.name, names: names)
            return """

                public init(_ observer: consuming \(names.observerTypeName)<\(initialType)>) {
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
            let stateType = stateTypeName(for: state.name, names: names)
            return """
                public borrowing func \(methodName)<R>(_ body: (borrowing \(names.observerTypeName)<\(stateType)>) throws -> R) rethrows -> R? {
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
            let callArgs = params.map { "\($0.name): \($0.name)" }.joined(separator: ", ")

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
                /// Attempts the `\(signature.event)` transition from the current wrapper state.
                public consuming func \(signature.event)(\(signatureParams)) async throws -> Self {
                    switch consume self {
            \(switchCases)
                    }
                }
            """
        }.joined(separator: "\n\n")

        return """
        // MARK: - \(names.machineTypeName) Combined State

        /// A runtime-friendly wrapper over all observer states.
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
        let initialStateType = ast.states
            .first(where: { $0.kind == .initial })
            .map { stateTypeName(for: $0.name, names: names) }
            ?? "\(names.machineNamespaceTypeName).Initial"
        let parameters = ast.factory?.parameters ?? []

        let propertyFunctionType: String = {
            let paramTypes = parameters.map(\.type)
            if paramTypes.isEmpty {
                return "@Sendable () -> \(names.observerTypeName)<\(initialStateType)>"
            }
            return "@Sendable (\(paramTypes.joined(separator: ", "))) -> \(names.observerTypeName)<\(initialStateType)>"
        }()

        return """
        // MARK: - \(names.machineTypeName) Client

        /// Dependency client entry point for constructing \(names.machineTypeName) observers.
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
            /// Accessor for the generated \(names.clientTypeName) dependency.
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

    private func stateTypeName(for stateName: String, names: Names) -> String {
        "\(names.machineNamespaceTypeName).\(stateName)"
    }

    private func transitionPropertyName(for transition: MachineAST.TransitionNode) -> String {
        transitionPropertyName(for: transitionSignature(for: transition))
    }

    private func transitionSignature(for transition: MachineAST.TransitionNode) -> TransitionSignature {
        .init(
            event: transition.event,
            parameters: transition.parameters.map { .init(name: $0.name, type: $0.type) }
        )
    }

    private func orderedTransitionSignatures(in ast: MachineAST) -> [TransitionSignature] {
        ast.transitions.reduce(into: [TransitionSignature]()) { partial, transition in
            let signature = transitionSignature(for: transition)
            if !partial.contains(signature) {
                partial.append(signature)
            }
        }
    }

    private func transitions(for signature: TransitionSignature, in ast: MachineAST) -> [MachineAST.TransitionNode] {
        ast.transitions.filter { transitionSignature(for: $0) == signature }
    }

    private func transitionPropertyName(for signature: TransitionSignature) -> String {
        let suffix = signature.parameters
            .map { parameter -> String in
                [
                    normalizedTypeName(parameter.name),
                    normalizedTypeName(parameter.type)
                ]
                .joined()
            }
            .joined()

        return "_\(lowerCamelName(from: signature.event))\(suffix)"
    }

    private func transitionAliasName(for signature: TransitionSignature) -> String {
        "\(normalizedTypeName(signature.event))\(transitionParameterSuffix(for: signature))Transition"
    }

    private func transitionBuilderName(for signature: TransitionSignature) -> String {
        lowerCamelName(from: "\(signature.event)\(transitionParameterSuffix(for: signature))Transition")
    }

    private func transitionParameterSuffix(for signature: TransitionSignature) -> String {
        signature.parameters
            .map { parameter in
                normalizedTypeName(parameter.name) + normalizedTypeName(parameter.type)
            }
            .joined()
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
        let machineNamespaceTypeName: String
        let observerTypeName: String
        let clientTypeName: String
        let stateWrapperTypeName: String
        let dependencyKeyName: String

        init(from machineName: String) {
            let machineType = SwiftCodeEmitter().normalizedTypeName(machineName)
            self.machineTypeName = machineType
            self.machineNamespaceTypeName = "\(machineType)Machine"
            self.observerTypeName = "\(machineType)Observer"
            self.clientTypeName = "\(machineType)Client"
            self.stateWrapperTypeName = "\(machineType)State"
            self.dependencyKeyName = SwiftCodeEmitter().lowerCamelName(from: machineType)
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

/// Backward-compatible alias for the native Swift emitter.
public typealias UrkelEmitter = SwiftCodeEmitter

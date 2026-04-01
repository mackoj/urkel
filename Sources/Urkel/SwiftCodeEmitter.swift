import Foundation

// `EmittedFiles` is defined in Sources/Urkel/Emitter/EmittedFiles.swift (v2).

/// Native Swift code emitter used for the default Urkel generation path (v1).
public struct SwiftCodeEmitter {
    public init() {}

    private func isClosureCapturedMode(_ ast: MachineAST) -> Bool {
        ast.contextType == nil && ast.composedMachines.isEmpty && !ast.continuations.isEmpty
    }

    public func emit(
        ast: MachineAST,
        composedASTs: [String: MachineAST] = [:],
        swiftImportsOverride: [String]? = nil,
        nonescapable: Bool = false
    ) -> EmittedFiles {
        let names = Names(from: ast.machineName)
        let imports = emitImports(for: ast, swiftImportsOverride: swiftImportsOverride)

        if isClosureCapturedMode(ast) {
            let smBody = [
                emitStateMachineFileClosure(for: ast, names: names),
                emitExtensionsClosure(for: ast, names: names),
                emitCombinedStateWrapper(for: ast, names: names, closureCaptured: true),
            ].filter { !$0.isEmpty }.joined(separator: "\n\n")

            let clientBody = emitClientStructClosure(for: ast, names: names)
            let dependencyBody = emitDependencyExtensions(for: ast, names: names)

            return EmittedFiles(
                stateMachine: [imports, smBody].filter { !$0.isEmpty }.joined(separator: "\n\n"),
                client: [imports, clientBody].filter { !$0.isEmpty }.joined(separator: "\n\n"),
                dependency: [imports, dependencyBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
            )
        }

        let stateMachineBody = [
            emitStateMachineFile(for: ast, names: names, nonescapable: nonescapable),
            emitExtensions(for: ast, names: names),
            emitCombinedStateWrapper(for: ast, names: names),
            emitComposedForwardingMethods(for: ast, composedASTs: composedASTs, names: names),
        ].filter { !$0.isEmpty }.joined(separator: "\n\n")

        let clientBody = [
            emitClientRuntimeBuilder(for: ast, names: names),
            emitClientStruct(for: ast, names: names),
        ].filter { !$0.isEmpty }.joined(separator: "\n\n")

        let dependencyBody = emitDependencyExtensions(for: ast, names: names)

        return EmittedFiles(
            stateMachine: [imports, stateMachineBody].filter { !$0.isEmpty }.joined(separator: "\n\n"),
            client: [imports, clientBody].filter { !$0.isEmpty }.joined(separator: "\n\n"),
            dependency: [imports, dependencyBody].filter { !$0.isEmpty }.joined(separator: "\n\n")
        )
    }

    /// Backward-compatible single-file emission. Prefer `emit()` for the 3-file split.
    public func emitUnified(
        ast: MachineAST,
        composedASTs: [String: MachineAST] = [:],
        swiftImportsOverride: [String]? = nil,
        nonescapable: Bool = false
    ) -> String {
        let files = emit(ast: ast, composedASTs: composedASTs, swiftImportsOverride: swiftImportsOverride, nonescapable: nonescapable)
        return [files.stateMachine, files.client, files.dependency]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func emitImports(
        for ast: MachineAST,
        swiftImportsOverride: [String]?
    ) -> String {
        var lines: [String] = []
        let allImports = swiftImportsOverride
            ?? ast.emitterOptions?.swiftImports
            ?? (ast.imports.isEmpty ? ["Foundation"] : ast.imports)
        for item in allImports where !lines.contains("import \(item)") {
            lines.append("import \(item)")
        }
        if !lines.contains("import Dependencies") {
            lines.append("import Dependencies")
        }
        return lines.joined(separator: "\n")
    }

    private func emitStateMachineFile(for ast: MachineAST, names: Names, nonescapable: Bool = false) -> String {
        let contextType = ast.contextType ?? "\(names.stateWrapperTypeName)RuntimeContext"
        let signatures = orderedTransitionSignatures(in: ast)
        let composedMeta = ast.composedMachines.map { composedMachineMetadata(for: $0) }

        let closureProps = signatures.compactMap { signature -> String? in
            guard let exemplar = transitions(for: signature, in: ast).first else { return nil }
            let closureInput = ([contextType] + exemplar.parameters.map(\.type)).joined(separator: ", ")
            return "    fileprivate let \(transitionPropertyName(for: signature)): @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: "\n")

        let composedProps = composedMeta.map { meta in
            "    var \(meta.statePropertyName): \(meta.stateTypeName)?\n    let \(meta.makePropertyName): @Sendable () -> \(meta.stateTypeName)"
        }.joined(separator: "\n")

        let closureInitParams = signatures.compactMap { signature -> String? in
            guard let exemplar = transitions(for: signature, in: ast).first else { return nil }
            let closureInput = ([contextType] + exemplar.parameters.map(\.type)).joined(separator: ", ")
            return "        \(transitionPropertyName(for: signature)): @escaping @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: ",\n")

        let composedInitParams = composedMeta.flatMap { meta -> [String] in
            [
                "        \(meta.statePropertyName): consuming \(meta.stateTypeName)? = .none",
                "        \(meta.makePropertyName): @escaping @Sendable () -> \(meta.stateTypeName)"
            ]
        }.joined(separator: ",\n")

        let allInitParams = [closureInitParams, composedInitParams]
            .filter { !$0.isEmpty }
            .joined(separator: ",\n")

        let closureAssignments = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            let name = transitionPropertyName(for: signature)
            return "        self.\(name) = \(name)"
        }.joined(separator: "\n")

        let composedAssignments = composedMeta.flatMap { meta -> [String] in
            [
                "        self.\(meta.statePropertyName) = \(meta.statePropertyName)",
                "        self.\(meta.makePropertyName) = \(meta.makePropertyName)"
            ]
        }.joined(separator: "\n")

        let allAssignments = [closureAssignments, composedAssignments]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let conformances = nonescapable ? "~Copyable, ~Escapable" : "~Copyable"
        let propsSection = [
            closureProps.isEmpty ? nil : "\n\(closureProps)",
            composedProps.isEmpty ? nil : "\n\(composedProps)"
        ].compactMap { $0 }.joined()

        let advanceHelpers: String
        if composedMeta.isEmpty {
            advanceHelpers = ""
        } else {
            advanceHelpers = "\n\n" + composedMeta.map { meta in
                let closureExtractions = signatures.compactMap { sig -> String? in
                    guard transitions(for: sig, in: ast).first != nil else { return nil }
                    let p = transitionPropertyName(for: sig)
                    return "        let \(p) = self.\(p)"
                }.joined(separator: "\n")
                let initArgs = (
                    ["            internalContext: internalContext"] +
                    signatures.compactMap { sig -> String? in
                        guard transitions(for: sig, in: ast).first != nil else { return nil }
                        let p = transitionPropertyName(for: sig)
                        return "            \(p): \(p)"
                    } +
                    ["            \(meta.statePropertyName): next",
                     "            \(meta.makePropertyName): \(meta.makePropertyName)"]
                ).joined(separator: ",\n")
                return """
                    /// Advances the embedded \(meta.machineName) state machine using `body`.
                    internal consuming func _advancing\(normalizedTypeName(meta.machineName))State(
                        via body: (consuming \(meta.stateTypeName)) async throws -> \(meta.stateTypeName)?
                    ) async rethrows -> Self {
                        let internalContext = self.internalContext
                \(closureExtractions)
                        let \(meta.makePropertyName) = self.\(meta.makePropertyName)
                        let ble = self.\(meta.statePropertyName)
                        let next: \(meta.stateTypeName)?
                        if var sub = ble { next = try await body(consume sub) } else { next = .none }
                        return Self(
                \(initArgs)
                        )
                    }
                """
            }.joined(separator: "\n\n")
        }

        // Build flat top-level typestate marker enums
        let stateMarkers = ast.states.map { state in
            let declaration = "public enum \(names.stateWrapperTypeName)\(normalizedTypeName(state.name)) {}"
            let docs = emitDocComments(state.docComments, indentation: "")
            return docs.isEmpty ? declaration : "\(docs)\n\(declaration)"
        }.joined(separator: "\n")

        let runtimeContextDecl = ast.contextType == nil
            ? "\ninternal struct \(names.stateWrapperTypeName)RuntimeContext: Sendable {\n    init() {}\n}"
            : ""

        return """
        // MARK: - \(names.machineTypeName) Typestate Markers

        \(stateMarkers)\(runtimeContextDecl)

        // MARK: - \(names.machineTypeName) State Machine

        /// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
        public struct \(names.machineStructTypeName)<State>: \(conformances) {
            private var internalContext: \(contextType)
        \(propsSection)
            internal init(
                internalContext: \(contextType)\(allInitParams.isEmpty ? "" : ",\n\(allInitParams)")
            ) {
                self.internalContext = internalContext
        \(allAssignments.isEmpty ? "" : "\n\(allAssignments)")
            }

            /// Access the internal context while preserving borrowing semantics.
            internal borrowing func withInternalContext<R>(_ body: (borrowing \(contextType)) throws -> R) rethrows -> R {
                try body(self.internalContext)
            }\(advanceHelpers)
        }
        """
    }

    private func emitClientRuntimeBuilder(for ast: MachineAST, names: Names) -> String {
        let contextType = ast.contextType ?? "\(names.stateWrapperTypeName)RuntimeContext"
        let signatures = orderedTransitionSignatures(in: ast)
        guard !signatures.isEmpty else { return "" }

        let factoryName = ast.factory?.name ?? "makeObserver"
        let factoryParameters = ast.factory?.parameters ?? []
        let composedMeta = ast.composedMachines.map { composedMachineMetadata(for: $0) }

        let initialContextTypeAlias: String = {
            let paramTypes = factoryParameters.map(\.type)
            if paramTypes.isEmpty {
                return "@Sendable () -> \(contextType)"
            }
            return "@Sendable (\(paramTypes.joined(separator: ", "))) -> \(contextType)"
        }()

        let closureAliases = signatures.compactMap { signature -> String? in
            guard let exemplar = transitions(for: signature, in: ast).first else { return nil }
            let closureInput = ([contextType] + exemplar.parameters.map(\.type)).joined(separator: ", ")
            return "    typealias \(transitionAliasName(for: signature)) = @Sendable (\(closureInput)) async throws -> \(contextType)"
        }.joined(separator: "\n")

        let properties = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            return "    let \(transitionBuilderName(for: signature)): \(transitionAliasName(for: signature))"
        }.joined(separator: "\n")

        let factoryInitArgs = factoryParameters.map(\.name).joined(separator: ", ")

        // Factory closure parameter list: original params + one per composed machine
        let allClosureParamNames: [String] = factoryParameters.map(\.name)
            + composedMeta.map { "make\(normalizedTypeName($0.machineName))" }
        let factoryClosureSignature: String = allClosureParamNames.isEmpty
            ? "" : "\(allClosureParamNames.joined(separator: ", ")) in"

        let initParams = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            return "\(transitionBuilderName(for: signature)): @escaping \(transitionAliasName(for: signature))"
        }.joined(separator: ",\n        ")
        let initParamList = (["initialContext: @escaping InitialContextBuilder"] + (initParams.isEmpty ? [] : [initParams]))
            .joined(separator: ",\n        ")

        let assignments = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            let builder = transitionBuilderName(for: signature)
            return "        self.\(builder) = \(builder)"
        }.joined(separator: "\n")
        let assignmentBlock = (["        self.initialContext = initialContext"]
            + (assignments.isEmpty ? [] : [assignments])).joined(separator: "\n")

        let initialState = ast.states.first(where: { $0.kind == .initial }).map(\.name) ?? "Initial"
        let initialStateType = stateTypeName(for: initialState, names: names)

        // Observer constructor args: closures, then composed machine slots
        let closureObserverArgs = signatures.compactMap { signature -> String? in
            guard transitions(for: signature, in: ast).first != nil else { return nil }
            return "\(transitionPropertyName(for: signature)): runtime.\(transitionBuilderName(for: signature))"
        }.joined(separator: ",\n                ")

        let composedObserverArgs = composedMeta.map { meta -> String in
            let paramName = "make\(normalizedTypeName(meta.machineName))"
            return "\(meta.makePropertyName): \(paramName)"
        }.joined(separator: ",\n                ")

        let allObserverArgs: String = {
            let parts = [closureObserverArgs, composedObserverArgs].filter { !$0.isEmpty }
            guard !parts.isEmpty else { return "" }
            return ",\n                " + parts.joined(separator: ",\n                ")
        }()

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
                        return \(names.machineStructTypeName)<\(initialStateType)>(
                            internalContext: context\(allObserverArgs)
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
        let composedMeta = ast.composedMachines.map { composedMachineMetadata(for: $0) }

        return orderedStates.compactMap { fromState in
            guard let stateTransitions = grouped[fromState] else { return nil }
            let methods = stateTransitions.compactMap { transition -> String? in
                guard let toState = transition.to else { return nil }
                let params = transition.parameters
                let destinationType = stateTypeName(for: toState, names: names)
                let signatureParams = params.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let callArgs = params.map { $0.name }.joined(separator: ", ")
                let methodDocs = if transition.docComments.isEmpty {
                    "    /// Handles the `\(transition.event)` transition from \(fromState) to \(toState)."
                } else {
                    emitDocComments(transition.docComments, indentation: "    ")
                }

                let closurePassThrough = orderedTransitionSignatures(in: ast).compactMap { signature -> String? in
                    guard self.transitions(for: signature, in: ast).first != nil else { return nil }
                    let closureName = transitionPropertyName(for: signature)
                    return "                \(closureName): self.\(closureName)"
                }.joined(separator: ",\n")

                // For each composed machine: spawn on fork transition, carry forward otherwise.
                let composedPassThrough = composedMeta.map { meta -> String in
                    let stateArg: String
                    if transition.spawnedMachine == meta.machineName {
                        stateArg = "                \(meta.statePropertyName): self.\(meta.makePropertyName)()"
                    } else {
                        stateArg = "                \(meta.statePropertyName): self.\(meta.statePropertyName)"
                    }
                    let makeArg = "                \(meta.makePropertyName): self.\(meta.makePropertyName)"
                    return "\(stateArg),\n\(makeArg)"
                }.joined(separator: ",\n")

                let allPassThrough = [closurePassThrough, composedPassThrough]
                    .filter { !$0.isEmpty }
                    .joined(separator: ",\n")

                return """
                \(methodDocs)
                    public consuming func \(transition.event)(\(signatureParams)) async throws -> \(names.machineStructTypeName)<\(destinationType)> {
                        let nextContext = try await self.\(transitionPropertyName(for: transition))(self.internalContext\(callArgs.isEmpty ? "" : ", \(callArgs)"))
                        return \(names.machineStructTypeName)<\(destinationType)>(
                            internalContext: nextContext\(allPassThrough.isEmpty ? "" : ",\n\(allPassThrough)")
                        )
                    }
                """
            }.joined(separator: "\n\n")

            let fromStateType = stateTypeName(for: fromState, names: names)
            return """
            // MARK: - \(names.machineTypeName).\(fromState) Transitions

            extension \(names.machineStructTypeName) where State == \(fromStateType) {
            \(methods)
            }
            """
        }.joined(separator: "\n\n")
    }

    private func emitCombinedStateWrapper(for ast: MachineAST, names: Names, closureCaptured: Bool = false) -> String {
        guard !ast.states.isEmpty else { return "" }

        let cases = ast.states
            .map { state in
                let stateType = stateTypeName(for: state.name, names: names)
                return "    case \(caseName(for: state.name))(\(names.machineStructTypeName)<\(stateType)>)"
            }
            .joined(separator: "\n")

        let initialInit: String = {
            guard let initial = ast.states.first(where: { $0.kind == .initial }) else { return "" }
            let initialType = stateTypeName(for: initial.name, names: names)
            return """

                public init(_ machine: consuming \(names.machineStructTypeName)<\(initialType)>) {
                    self = .\(caseName(for: initial.name))(machine)
                }
            """
        }()

        let unwraps = ast.states.map { state in
            let methodName = "with\(normalizedTypeName(state.name))"
            let stateCase = caseName(for: state.name)
            let stateType = stateTypeName(for: state.name, names: names)
            return """
                public borrowing func \(methodName)<R>(_ body: (borrowing \(names.machineStructTypeName)<\(stateType)>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .\(stateCase)(observer):
                        return try body(observer)
                    default:
                        return nil
                    }
                }
            """
        }.joined(separator: "\n\n")

        var orderedSignatures: [TransitionSignature] = []
        var transitionsBySignature: [TransitionSignature: [MachineAST.TransitionNode]] = [:]
        for transition in ast.transitions {
            guard transition.to != nil else { continue }
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

            let switchCases: String
            if closureCaptured {
                // mutating mode: assign to self, no return, no try
                switchCases = ast.states.map { state in
                    let currentCase = caseName(for: state.name)
                    if let transition = transitionByFrom[state.name] {
                        let destinationCase = caseName(for: transition.to!)
                        let callExpr = callArgs.isEmpty
                            ? "await observer.\(signature.event)()"
                            : "await observer.\(signature.event)(\(callArgs))"
                        return """
                                case let .\(currentCase)(observer):
                                    self = .\(destinationCase)(\(callExpr))
                            """
                    }
                    return """
                            case let .\(currentCase)(observer):
                                self = .\(currentCase)(observer)
                        """
                }.joined(separator: "\n")
            } else {
                switchCases = ast.states.map { state in
                    let currentCase = caseName(for: state.name)
                    if let transition = transitionByFrom[state.name] {
                        let destinationCase = caseName(for: transition.to!)
                        let callExpr = callArgs.isEmpty
                            ? "try await observer.\(signature.event)()"
                            : "try await observer.\(signature.event)(\(callArgs))"
                        return """
                                case let .\(currentCase)(observer):
                                    return .\(destinationCase)(\(callExpr))
                            """
                    }
                    return """
                            case let .\(currentCase)(observer):
                                return .\(currentCase)(observer)
                        """
                }.joined(separator: "\n")
            }

            if closureCaptured {
                return """
                    /// Attempts the `\(signature.event)` transition from the current wrapper state.
                    public mutating func \(signature.event)(\(signatureParams)) async {
                        switch consume self {
                \(switchCases)
                        }
                    }
                """
            } else {
                return """
                    /// Attempts the `\(signature.event)` transition from the current wrapper state.
                    public consuming func \(signature.event)(\(signatureParams)) async throws -> Self {
                        switch consume self {
                \(switchCases)
                        }
                    }
                """
            }
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

    // MARK: - Composed Machine Forwarding Methods

    private func emitComposedForwardingMethods(
        for ast: MachineAST,
        composedASTs: [String: MachineAST],
        names: Names
    ) -> String {
        guard !ast.composedMachines.isEmpty else { return "" }

        let sections = ast.composedMachines.compactMap { composedMachineName -> String? in
            guard let composedAST = composedASTs[composedMachineName] else { return nil }
            let _ = composedMachineMetadata(for: composedMachineName)
            let carryingStates = composedCarryingStates(composedMachineName: composedMachineName, in: ast)
            let prefix = lowerCamelAcronymAwareName(from: composedMachineName)

            let methods = orderedTransitionSignatures(in: composedAST).compactMap { signature -> String? in
                guard let exemplar = transitions(for: signature, in: composedAST).first else { return nil }
                let params = exemplar.parameters
                let signatureParams = params.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let callArgs = params.map { "\($0.name): \($0.name)" }.joined(separator: ", ")
                let methodName = "\(prefix)\(normalizedTypeName(signature.event))"

                let switchCases = ast.states.map { state -> String in
                    let stateCase = caseName(for: state.name)
                    let advanceMethod = "_advancing\(normalizedTypeName(composedMachineName))State"
                    if carryingStates.contains(state.name) {
                        let callExpr = callArgs.isEmpty
                            ? "try await ble.\(signature.event)()"
                            : "try await ble.\(signature.event)(\(callArgs))"
                        return """
                            case let .\(stateCase)(obs):
                                return .\(stateCase)(try await obs.\(advanceMethod) { ble in \(callExpr) })
                        """
                    } else {
                        return """
                            case let .\(stateCase)(obs):
                                return .\(stateCase)(obs)
                        """
                    }
                }.joined(separator: "\n")

                return """
                    /// Forwards the `\(signature.event)` event to the embedded \(composedMachineName) machine.
                    public consuming func \(methodName)(\(signatureParams)) async throws -> Self {
                        switch consume self {
                \(switchCases)
                        }
                    }
                """
            }.joined(separator: "\n\n")

            guard !methods.isEmpty else { return nil }
            return """
            extension \(names.stateWrapperTypeName) {
            \(methods)
            }
            """
        }

        return sections.joined(separator: "\n\n")
    }

    /// Returns the set of parent-machine state names that carry the composed machine's state
    /// (all states reachable from the fork transition's destination, inclusive).
    private func composedCarryingStates(composedMachineName: String, in ast: MachineAST) -> Set<String> {
        let forkTargets = ast.transitions
            .filter { $0.spawnedMachine == composedMachineName }
            .compactMap { $0.to }
        var result = Set(forkTargets)
        var queue = Array(forkTargets)
        while !queue.isEmpty {
            let state = queue.removeFirst()
            for transition in ast.transitions where transition.from == state {
                if let to = transition.to, result.insert(to).inserted {
                    queue.append(to)
                }
            }
        }
        return result
    }

    /// Builds `ComposedMachineMetadata` for a given composed machine name.
    private func composedMachineMetadata(for machineName: String) -> ComposedMachineMetadata {
        ComposedMachineMetadata(
            machineName: machineName,
            stateTypeName: "\(normalizedTypeName(machineName))State",
            statePropertyName: "_\(lowerCamelAcronymAwareName(from: machineName))State",
            makePropertyName: "_make\(normalizedTypeName(machineName))",
            factoryPropertyName: "make\(normalizedTypeName(machineName))State",
            shouldSpawnVariableName: "shouldSpawn\(normalizedTypeName(machineName))"
        )
    }

    private func emitClientStruct(for ast: MachineAST, names: Names) -> String {
        let factoryName = ast.factory?.name ?? "makeObserver"
        let initialStateType = ast.states
            .first(where: { $0.kind == .initial })
            .map { stateTypeName(for: $0.name, names: names) }
            ?? "\(names.stateWrapperTypeName)Initial"
        let parameters = ast.factory?.parameters ?? []
        let composedMeta = ast.composedMachines.map { composedMachineMetadata(for: $0) }

        let composedParamTypes = composedMeta.map { "@escaping @Sendable () -> \($0.stateTypeName)" }
        let allParamTypes = parameters.map(\.type) + composedParamTypes

        let propertyFunctionType: String = {
            if allParamTypes.isEmpty {
                return "@Sendable () -> \(names.machineStructTypeName)<\(initialStateType)>"
            }
            return "@Sendable (\(allParamTypes.joined(separator: ", "))) -> \(names.machineStructTypeName)<\(initialStateType)>"
        }()

        return """
        // MARK: - \(names.machineTypeName) Client

        /// Dependency client entry point for constructing \(names.machineTypeName) state machines.
        public struct \(names.clientTypeName): Sendable {
            public var \(factoryName): \(propertyFunctionType)

            public init(\(factoryName): @escaping \(propertyFunctionType)) {
                self.\(factoryName) = \(factoryName)
            }
        }
        """
    }

    private func emitDependencyExtensions(for ast: MachineAST, names: Names) -> String {
        let factoryName = ast.factory?.name ?? "makeObserver"
        let initialStateType = ast.states
            .first(where: { $0.kind == .initial })
            .map { stateTypeName(for: $0.name, names: names) }
            ?? "\(names.stateWrapperTypeName)Initial"
        let parameters = ast.factory?.parameters ?? []
        let composedMeta = ast.composedMachines.map { composedMachineMetadata(for: $0) }

        let composedParamTypes = composedMeta.map { "@escaping @Sendable () -> \($0.stateTypeName)" }
        let allParamTypes = parameters.map(\.type) + composedParamTypes

        let propertyFunctionType: String = {
            if allParamTypes.isEmpty {
                return "@Sendable () -> \(names.machineStructTypeName)<\(initialStateType)>"
            }
            return "@Sendable (\(allParamTypes.joined(separator: ", "))) -> \(names.machineStructTypeName)<\(initialStateType)>"
        }()
        _ = propertyFunctionType

        let placeholderCount = parameters.count + composedMeta.count

        return """
        extension \(names.clientTypeName): DependencyKey {
            public static let testValue = Self(
                \(factoryName): \(placeholderFactoryClosure(parameterCount: placeholderCount, message: "Configure \(names.clientTypeName).testValue in tests."))
            )

            public static let previewValue = Self(
                \(factoryName): \(placeholderFactoryClosure(parameterCount: placeholderCount, message: "Configure \(names.clientTypeName).previewValue in previews."))
            )

            /// The live production implementation.
            /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
            public static var liveValue: Self { .makeLive() }
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
        "\(names.stateWrapperTypeName)\(stateName)"
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
        ast.transitions
            .filter { $0.to != nil }
            .reduce(into: [TransitionSignature]()) { partial, transition in
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
            .map { normalizedTypeName($0.type) }
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
            .map { normalizedTypeName($0.type) }
            .joined()
    }

    internal func normalizedTypeName(_ raw: String) -> String {
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

    internal func lowerCamelName(from raw: String) -> String {
        let normalized = normalizedTypeName(raw)
        guard let first = normalized.first else { return normalized }
        return String(first).lowercased() + normalized.dropFirst()
    }

    private func lowerCamelAcronymAwareName(from raw: String) -> String {
        let normalized = normalizedTypeName(raw)
        guard !normalized.isEmpty else { return normalized }
        if normalized == normalized.uppercased() {
            return normalized.lowercased()
        }
        return lowerCamelName(from: normalized)
    }

    private func emitDocComments(_ comments: [MachineAST.DocComment], indentation: String) -> String {
        comments
            .map { "\(indentation)/// \($0.text)" }
            .joined(separator: "\n")
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
        let machineTypeName: String         // "FolderWatch"
        let machineStructTypeName: String   // "FolderWatchMachine"
        let stateWrapperTypeName: String    // "FolderWatchState" (combined wrapper + typestate prefix)
        let clientTypeName: String          // "FolderWatchClient"
        let dependencyKeyName: String       // "folderWatch"

        init(from machineName: String) {
            let machineType = SwiftCodeEmitter().normalizedTypeName(machineName)
            self.machineTypeName = machineType
            self.machineStructTypeName = "\(machineType)Machine"
            self.stateWrapperTypeName = "\(machineType)State"
            self.clientTypeName = "\(machineType)Client"
            self.dependencyKeyName = SwiftCodeEmitter().lowerCamelName(from: machineType)
        }
    }

    private struct ComposedMachineMetadata {
        let machineName: String
        let stateTypeName: String           // e.g. "BLEState"
        let statePropertyName: String       // e.g. "_bleState"
        let makePropertyName: String        // e.g. "_makeBLE"
        let factoryPropertyName: String     // legacy field kept for reference
        let shouldSpawnVariableName: String // legacy field kept for reference
    }

    private struct TransitionParameterSignature: Hashable {
        let name: String
        let type: String
    }

    private struct TransitionSignature: Hashable {
        let event: String
        let parameters: [TransitionParameterSignature]
    }
    // MARK: - Closure-Captured Mode Emission

    private func emitStateMachineFileClosure(for ast: MachineAST, names: Names) -> String {
        let factoryParams = ast.factory?.parameters ?? []

        let stateMarkers = ast.states.map { state in
            let declaration = "public enum \(names.stateWrapperTypeName)\(normalizedTypeName(state.name)) {}"
            let docs = emitDocComments(state.docComments, indentation: "")
            return docs.isEmpty ? declaration : "\(docs)\n\(declaration)"
        }.joined(separator: "\n")

        let stateChangingTransitions = ast.transitions.filter { $0.to != nil }
        let continuationTransitions = ast.transitions.filter { $0.to == nil }

        let factoryParamProps = factoryParams.map { "    public let \($0.name): \($0.type)" }.joined(separator: "\n")

        var seenSignatures = Set<String>()
        var closureProps: [String] = []
        for transition in stateChangingTransitions {
            let sig = transitionSignature(for: transition)
            let sigKey = sig.event + sig.parameters.map { $0.name + $0.type }.joined()
            guard !seenSignatures.contains(sigKey) else { continue }
            seenSignatures.insert(sigKey)
            guard let to = transition.to else { continue }
            let toType = stateTypeName(for: to, names: names)
            let paramTypes = transition.parameters.map(\.type)
            let closureType: String
            if paramTypes.isEmpty {
                closureType = "@Sendable () async -> \(names.machineStructTypeName)<\(toType)>"
            } else {
                closureType = "@Sendable (\(paramTypes.joined(separator: ", "))) async -> \(names.machineStructTypeName)<\(toType)>"
            }
            closureProps.append("    fileprivate let \(closurePropertyNameClosure(for: transition)): (\(closureType))?")
        }

        var seenContinuations = Set<String>()
        for transition in continuationTransitions {
            guard !seenContinuations.contains(transition.event) else { continue }
            seenContinuations.insert(transition.event)
            guard let returnType = ast.continuations[transition.event] else { continue }
            closureProps.append("    fileprivate let \(continuationPropertyNameClosure(for: transition.event)): (@Sendable () -> \(returnType))?")
        }

        var stateInits: [String] = []
        for state in ast.states {
            let outgoingStateChanging = stateChangingTransitions.filter { $0.from == state.name }
            let outgoingContinuation = continuationTransitions.filter { $0.from == state.name }
            let stateType = stateTypeName(for: state.name, names: names)

            var initParams: [String] = factoryParams.map { "        \($0.name): \($0.type)" }
            for transition in outgoingStateChanging {
                guard let to = transition.to else { continue }
                let toType = stateTypeName(for: to, names: names)
                let paramTypes = transition.parameters.map(\.type)
                let closureType: String
                if paramTypes.isEmpty {
                    closureType = "@escaping @Sendable () async -> \(names.machineStructTypeName)<\(toType)>"
                } else {
                    closureType = "@escaping @Sendable (\(paramTypes.joined(separator: ", "))) async -> \(names.machineStructTypeName)<\(toType)>"
                }
                initParams.append("        \(closureParamLabel(for: transition)): \(closureType)")
            }
            for transition in outgoingContinuation {
                guard let returnType = ast.continuations[transition.event] else { continue }
                initParams.append("        \(continuationParamLabel(for: transition.event)): @escaping @Sendable () -> \(returnType)")
            }

            var assignments: [String] = factoryParams.map { "        self.\($0.name) = \($0.name)" }

            var handledClosures = Set<String>()
            for transition in outgoingStateChanging {
                let sig = transitionSignature(for: transition)
                let sigKey = sig.event + sig.parameters.map { $0.name + $0.type }.joined()
                if !handledClosures.contains(sigKey) {
                    handledClosures.insert(sigKey)
                    assignments.append("        \(closurePropertyNameClosure(for: transition)) = \(closureParamLabel(for: transition))")
                }
            }
            var allHandledSigKeys = Set<String>()
            for transition in stateChangingTransitions {
                let sig = transitionSignature(for: transition)
                let sigKey = sig.event + sig.parameters.map { $0.name + $0.type }.joined()
                if !allHandledSigKeys.contains(sigKey) {
                    allHandledSigKeys.insert(sigKey)
                    if !handledClosures.contains(sigKey) {
                        assignments.append("        \(closurePropertyNameClosure(for: transition)) = nil")
                    }
                }
            }

            var handledContinuations = Set<String>()
            for transition in outgoingContinuation {
                if !handledContinuations.contains(transition.event) {
                    handledContinuations.insert(transition.event)
                    assignments.append("        \(continuationPropertyNameClosure(for: transition.event)) = \(continuationParamLabel(for: transition.event))")
                }
            }
            var nilledContinuations = Set<String>()
            for transition in continuationTransitions {
                if !handledContinuations.contains(transition.event), !nilledContinuations.contains(transition.event) {
                    nilledContinuations.insert(transition.event)
                    assignments.append("        \(continuationPropertyNameClosure(for: transition.event)) = nil")
                }
            }

            let stateKindComment = "    // MARK: \(normalizedTypeName(state.name)) State Init"
            let initParamList = initParams.joined(separator: ",\n")
            let assignmentBlock = assignments.joined(separator: "\n")

            stateInits.append("""
            \(stateKindComment)
                internal init(
            \(initParamList)
                ) where State == \(stateType) {
            \(assignmentBlock)
                }
            """)
        }

        let allProps = [factoryParamProps.isEmpty ? nil : factoryParamProps,
                        closureProps.isEmpty ? nil : closureProps.joined(separator: "\n")]
            .compactMap { $0 }.joined(separator: "\n\n")

        let allInits = stateInits.joined(separator: "\n\n")

        return """
        // MARK: - \(names.machineTypeName) Typestate Markers

        \(stateMarkers)

        // MARK: - \(names.machineTypeName) State Machine

        /// A type-safe state machine encoding the current state in its generic parameter.
        public struct \(names.machineStructTypeName)<State>: ~Copyable {
        \(allProps.isEmpty ? "" : "\(allProps)\n")
        \(allInits)
        }
        """
    }

    private func closurePropertyNameClosure(for transition: MachineAST.TransitionNode) -> String {
        "_\(lowerCamelName(from: transition.event))\(transitionParameterSuffix(for: transitionSignature(for: transition)))Transition"
    }

    private func continuationPropertyNameClosure(for eventName: String) -> String {
        "_\(lowerCamelName(from: eventName))Accessor"
    }

    private func closureParamLabel(for transition: MachineAST.TransitionNode) -> String {
        "\(lowerCamelName(from: transition.event))\(transitionParameterSuffix(for: transitionSignature(for: transition)))Transition"
    }

    private func continuationParamLabel(for eventName: String) -> String {
        "\(lowerCamelName(from: eventName))Accessor"
    }

    private func emitExtensionsClosure(for ast: MachineAST, names: Names) -> String {
        let grouped = Dictionary(grouping: ast.transitions, by: { $0.from })
        let orderedStates = ast.transitions.map(\.from).reduce(into: [String]()) { partial, state in
            if !partial.contains(state) { partial.append(state) }
        }

        return orderedStates.compactMap { fromState -> String? in
            let stateType = stateTypeName(for: fromState, names: names)
            let outgoing = grouped[fromState] ?? []

            var methods: [String] = []

            for transition in outgoing where transition.to != nil {
                guard let to = transition.to else { continue }
                let toType = stateTypeName(for: to, names: names)
                let params = transition.parameters
                let signatureParams = params.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
                let callArgs = params.map { $0.name }.joined(separator: ", ")
                let propName = closurePropertyNameClosure(for: transition)
                let methodDocs = transition.docComments.isEmpty
                    ? "    /// Handles the `\(transition.event)` transition from \(fromState) to \(to)."
                    : emitDocComments(transition.docComments, indentation: "    ")
                let callExpr = callArgs.isEmpty
                    ? "await \(propName)!()"
                    : "await \(propName)!(\(callArgs))"

                methods.append("""
                \(methodDocs)
                    public consuming func \(transition.event)(\(signatureParams)) async -> \(names.machineStructTypeName)<\(toType)> {
                        \(callExpr)
                    }
                """)
            }

            for transition in outgoing where transition.to == nil {
                guard let returnType = ast.continuations[transition.event] else { continue }
                let propName = continuationPropertyNameClosure(for: transition.event)
                let methodDocs = transition.docComments.isEmpty
                    ? "    /// Returns the \(transition.event) accessor while in the \(fromState) state."
                    : emitDocComments(transition.docComments, indentation: "    ")

                methods.append("""
                \(methodDocs)
                    public var \(transition.event): \(returnType) {
                        \(propName)!()
                    }
                """)
            }

            guard !methods.isEmpty else { return nil }

            return """
            // MARK: - \(names.machineTypeName).\(fromState) Transitions

            extension \(names.machineStructTypeName) where State == \(stateType) {
            \(methods.joined(separator: "\n\n"))
            }
            """
        }.joined(separator: "\n\n")
    }

    private func emitClientStructClosure(for ast: MachineAST, names: Names) -> String {
        let factoryName = ast.factory?.name ?? "makeObserver"
        let factoryParams = ast.factory?.parameters ?? []
        let initialStateName = ast.states.first(where: { $0.kind == .initial }).map(\.name) ?? "Initial"
        let initialStateType = stateTypeName(for: initialStateName, names: names)

        let paramTypes = factoryParams.map(\.type)
        let propertyFunctionType: String
        if paramTypes.isEmpty {
            propertyFunctionType = "@Sendable () -> \(names.machineStructTypeName)<\(initialStateType)>"
        } else {
            propertyFunctionType = "@Sendable (\(paramTypes.joined(separator: ", "))) -> \(names.machineStructTypeName)<\(initialStateType)>"
        }

        let noop = buildNoopMachine(for: ast, names: names, factoryParams: factoryParams, stateName: initialStateName, indent: "            ")

        let paramNames = factoryParams.map(\.name)
        let closureSignature = paramNames.isEmpty ? "" : "\(paramNames.joined(separator: ", ")) in\n            "

        return """
        // MARK: - \(names.machineTypeName) Client

        /// Dependency client entry point for constructing \(names.machineTypeName) state machines.
        public struct \(names.clientTypeName): Sendable {
            public var \(factoryName): \(propertyFunctionType)

            public init(\(factoryName): @escaping \(propertyFunctionType)) {
                self.\(factoryName) = \(factoryName)
            }

            /// No-op implementation that performs no real side effects.
            public static var noop: Self {
                Self(\(factoryName): { \(closureSignature)\(noop)
                })
            }
        }
        """
    }

    private func buildNoopMachine(for ast: MachineAST, names: Names, factoryParams: [MachineAST.Parameter], stateName: String, indent: String, visited: Set<String> = []) -> String {
        let stateType = stateTypeName(for: stateName, names: names)
        let outgoingStateChanging = ast.transitions.filter { $0.from == stateName && $0.to != nil }
        let outgoingContinuation = ast.transitions.filter { $0.from == stateName && $0.to == nil }

        let factoryParamNames = factoryParams.map(\.name)

        if outgoingStateChanging.isEmpty && outgoingContinuation.isEmpty {
            let factoryArgs = factoryParamNames.map { "\($0): \($0)" }.joined(separator: ",\n\(indent)    ")
            let argStr = factoryArgs.isEmpty ? "" : "\n\(indent)    \(factoryArgs)\n\(indent)"
            return "\(names.machineStructTypeName)<\(stateType)>(\(argStr))"
        }

        var args: [String] = factoryParamNames.map { "\($0): \($0)" }

        var seenSigs = Set<String>()
        for transition in outgoingStateChanging {
            guard let to = transition.to else { continue }
            let sig = transitionSignature(for: transition)
            let sigKey = sig.event + sig.parameters.map { $0.name + $0.type }.joined()
            guard !seenSigs.contains(sigKey) else { continue }
            seenSigs.insert(sigKey)

            let paramLabel = closureParamLabel(for: transition)
            let paramCount = transition.parameters.count
            let nextIndent = indent + "        "

            let closureParam: String
            if visited.contains(to) {
                // Break cycle: self-loop or back-edge — noop can't meaningfully recurse
                let ignores = paramCount == 0 ? "" : (0..<paramCount).map { _ in "_" }.joined(separator: ", ") + " in "
                closureParam = "{ \(ignores)fatalError(\"Noop does not support cyclic '\(transition.event)' transition\") }"
            } else {
                let innerMachine = buildNoopMachine(for: ast, names: names, factoryParams: factoryParams, stateName: to, indent: nextIndent, visited: visited.union([stateName]))
                if paramCount == 0 {
                    closureParam = "{ \(innerMachine) }"
                } else {
                    let ignores = (0..<paramCount).map { _ in "_" }.joined(separator: ", ")
                    closureParam = "{ \(ignores) in \(innerMachine) }"
                }
            }
            args.append("\(paramLabel): \(closureParam)")
        }

        var seenConts = Set<String>()
        for transition in outgoingContinuation {
            guard !seenConts.contains(transition.event) else { continue }
            seenConts.insert(transition.event)
            let paramLabel = continuationParamLabel(for: transition.event)
            args.append("\(paramLabel): { AsyncThrowingStream { $0.finish() } }")
        }

        let argsStr = args.map { "\(indent)    \($0)" }.joined(separator: ",\n")
        return "\(names.machineStructTypeName)<\(stateType)>(\n\(argsStr)\n\(indent))"
    }

}

/// Backward-compatible alias for the native Swift emitter.
public typealias UrkelEmitter = SwiftCodeEmitter

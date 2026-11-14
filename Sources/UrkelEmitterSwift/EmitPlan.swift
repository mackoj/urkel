import UrkelAST

extension SwiftSyntaxEmitter {
    /// What the emitter derives from a `UrkelFile`, computed once per `emit(file:)`.
    ///
    /// Emission asks the same questions for every state and transition: a state's outgoing transitions and hooks,
    /// every closure the machine stores, which states run a timer. Answering them from the file each time made
    /// emitting a machine cubic in its number of transitions. The members the emitter reads from a file have the
    /// same names here, so the emitter reads a plan where it used to read the file.
    struct EmitPlan {
        let machineName: String
        let contextType: String?
        let states: [StateDecl]
        let imports: [ImportDecl]
        let entryExitHooks: [EntryExitDecl]
        let transitionStmts: [TransitionStmt]
        let reactiveStmts: [ReactiveStmt]
        let simpleStates: [SimpleStateDecl]
        let initState: SimpleStateDecl?

        let compoundStates: [CompoundStateDecl]
        /// The first compound state and the first simple state with each name, as `first(where:)` finds them.
        let compoundStatesByName: [String: CompoundStateDecl]
        let simpleStatesByName: [String: SimpleStateDecl]
        /// Top-level transitions by the name of their source state, in source order.
        let outgoing: [String: [TransitionStmt]]
        /// Every closure the machine stores for a transition, in the order they are first used.
        let closureInfos: [TransitionClosureInfo]
        /// The closure property names of top-level, standard-arrow event transitions.
        let topLevelEventPropNames: Set<String>
        let actionNames: [String]
        let guardNames: [String]
        let statesWithData: [SimpleStateDecl]
        let statesWithTimers: [SimpleStateDecl]
        let timerStateNames: Set<String>
        let subMachineImports: [ImportDecl]
        let entryActions: [String: [String]]
        let exitActions: [String: [String]]
        /// `source.event` pairs whose top-level, standard-arrow transitions include a guarded one: each of their
        /// transitions stores its own closure, named after its destination.
        private let guardedEvents: Set<SourceEvent>

        init(_ file: UrkelFile) {
            machineName = file.machineName
            contextType = file.contextType
            states = file.states
            imports = file.imports
            entryExitHooks = file.entryExitHooks
            let transitionStmts = file.transitionStmts
            self.transitionStmts = transitionStmts
            reactiveStmts = file.reactiveStmts
            let simpleStates = file.simpleStates
            self.simpleStates = simpleStates
            initState = file.initState

            let compoundStates = file.states.compactMap { state -> CompoundStateDecl? in
                guard case .compound(let compound) = state else { return nil }
                return compound
            }
            self.compoundStates = compoundStates
            compoundStatesByName = Dictionary(compoundStates.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
            simpleStatesByName = Dictionary(simpleStates.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

            var outgoing: [String: [TransitionStmt]] = [:]
            var guardedEvents = Set<SourceEvent>()
            var timerSources = Set<String>()
            for t in transitionStmts {
                guard case .state(let ref) = t.source else { continue }
                outgoing[ref.name, default: []].append(t)
                switch t.event {
                case .event(let ev) where t.arrow == .standard && t.guard != nil:
                    guardedEvents.insert(SourceEvent(source: ref.name, event: ev.name))
                case .timer where t.arrow == .standard:
                    timerSources.insert(ref.name)
                default:
                    break
                }
            }
            self.outgoing = outgoing
            self.guardedEvents = guardedEvents
            let statesWithTimers = simpleStates.filter { timerSources.contains($0.name) }
            self.statesWithTimers = statesWithTimers
            timerStateNames = Set(statesWithTimers.map(\.name))
            statesWithData = simpleStates.filter { !$0.params.isEmpty }

            var seen = Set<String>()
            var closureInfos: [TransitionClosureInfo] = []
            for t in transitionStmts + compoundStates.flatMap(\.innerTransitions) {
                // Standard event transitions
                if case .event(let ev) = t.event, t.arrow == .standard {
                    let propName = Self.transitionPropName(for: t, guardedEvents: guardedEvents)
                    if seen.insert(propName).inserted {
                        closureInfos.append(TransitionClosureInfo(
                            event: ev.name,
                            propName: propName,
                            params: ev.params.map { Parameter(label: $0.label, typeExpr: $0.typeExpr) }
                        ))
                    }
                }
                // Timer transitions — closure takes (Ctx) -> Ctx with no event params
                if case .timer(_) = t.event, t.arrow == .standard, let dest = t.destination {
                    let propName = "_timerTo\(typeName(from: dest.name))"
                    if seen.insert(propName).inserted {
                        closureInfos.append(TransitionClosureInfo(
                            event: "timerTo\(typeName(from: dest.name))",
                            propName: propName,
                            params: []
                        ))
                    }
                }
            }
            self.closureInfos = closureInfos
            topLevelEventPropNames = Set(transitionStmts.compactMap { t in
                guard case .event(_) = t.event, t.arrow == .standard else { return nil }
                return Self.transitionPropName(for: t, guardedEvents: guardedEvents)
            })

            var actionNames: [String] = []
            var seenActions = Set<String>()
            for t in transitionStmts {
                for a in (t.action?.actions ?? []) where seenActions.insert(a).inserted { actionNames.append(a) }
            }
            for hook in file.entryExitHooks {
                for a in hook.actions where seenActions.insert(a).inserted { actionNames.append(a) }
            }
            for r in reactiveStmts {
                for a in (r.action?.actions ?? []) where seenActions.insert(a).inserted { actionNames.append(a) }
            }
            self.actionNames = actionNames

            var guardNames: [String] = []
            var seenGuards = Set<String>()
            for t in transitionStmts {
                switch t.guard {
                case .named(let n), .negated(let n):
                    if seenGuards.insert(n).inserted { guardNames.append(n) }
                case .else, nil:
                    break
                }
            }
            self.guardNames = guardNames

            var entryActions: [String: [String]] = [:]
            var exitActions: [String: [String]] = [:]
            for hook in file.entryExitHooks {
                switch hook.hook {
                case .entry: entryActions[hook.state.name, default: []].append(contentsOf: hook.actions)
                case .exit:  exitActions[hook.state.name, default: []].append(contentsOf: hook.actions)
                }
            }
            self.entryActions = entryActions
            self.exitActions = exitActions

            let forkMachines = Set(transitionStmts.compactMap { $0.fork?.machine })
            let reactiveMachines = Set(reactiveStmts.compactMap { r -> String? in
                if case .machine(let n) = r.source.target { return n }
                return nil
            })
            let referenced = forkMachines.union(reactiveMachines)
            subMachineImports = file.imports.filter { referenced.contains($0.name) }
        }

        /// The property that stores the closure for transition `t`.
        func transitionPropName(for t: TransitionStmt) -> String {
            Self.transitionPropName(for: t, guardedEvents: guardedEvents)
        }

        private static func transitionPropName(for t: TransitionStmt, guardedEvents: Set<SourceEvent>) -> String {
            guard case .event(let ev) = t.event, case .state(let ref) = t.source else { return "_unknown" }
            if guardedEvents.contains(SourceEvent(source: ref.name, event: ev.name)), let dest = t.destination {
                return "_\(variableName(from: typeName(from: ev.name)))To\(typeName(from: dest.name))"
            } else {
                return closurePropertyName(for: ev.name, params: ev.params.map { Parameter(label: $0.label, typeExpr: $0.typeExpr) })
            }
        }

        private struct SourceEvent: Hashable {
            let source: String
            let event: String
        }
    }
}

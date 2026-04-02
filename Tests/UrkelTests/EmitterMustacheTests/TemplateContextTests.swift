import Testing
@testable import UrkelAST
@testable import UrkelEmitterMustache

// MARK: - Helpers

private func simple(_ kind: StateKind, _ name: String, params: [Parameter] = []) -> StateDecl {
    .simple(SimpleStateDecl(kind: kind, params: params, name: name))
}

private func trans(
    from: String,
    event: String,
    to: String,
    guard g: GuardClause? = nil,
    action: ActionClause? = nil,
    arrow: Arrow = .standard,
    fork: ForkClause? = nil
) -> TransitionDecl {
    .transition(TransitionStmt(
        source: .state(StateRef(from)),
        arrow: arrow,
        event: .event(EventDecl(name: event)),
        guard: g,
        destination: StateRef(to),
        fork: fork,
        action: action
    ))
}

// MARK: - UrkelFile templateContext Tests

@Suite("UrkelEmitterMustache — templateContext keys")
struct TemplateContextTests {

    // MARK: machineName / machineTypeName / machineVariableName

    @Test("machineName key matches file name")
    func machineNameKey() {
        let file = UrkelFile(machineName: "FolderWatch", states: [simple(.`init`, "Idle"), simple(.final, "Done")])
        let ctx = file.templateContext
        #expect(ctx["machineName"] as? String == "FolderWatch")
    }

    @Test("machineTypeName is PascalCase")
    func machineTypeNamePascalCase() {
        let file = UrkelFile(machineName: "folder-watch", states: [])
        let ctx = file.templateContext
        let tn = ctx["machineTypeName"] as? String ?? ""
        #expect(tn.first?.isUppercase == true)
    }

    @Test("machineVariableName is camelCase")
    func machineVariableNameCamelCase() {
        let file = UrkelFile(machineName: "FolderWatch", states: [])
        let ctx = file.templateContext
        let vn = ctx["machineVariableName"] as? String ?? ""
        #expect(vn.first?.isLowercase == true)
    }

    // MARK: contextType / hasContext

    @Test("hasContext is false when contextType is nil")
    func hasContextFalseWhenNil() {
        let file = UrkelFile(machineName: "M", states: [])
        let ctx = file.templateContext
        #expect(ctx["hasContext"] as? Bool == false)
    }

    @Test("hasContext is true when contextType is set")
    func hasContextTrueWhenSet() {
        let file = UrkelFile(machineName: "M", contextType: "MyContext", states: [])
        let ctx = file.templateContext
        #expect(ctx["hasContext"] as? Bool == true)
        #expect(ctx["contextType"] as? String == "MyContext")
    }

    // MARK: imports / composedMachines

    @Test("imports key contains declared @import names")
    func importsKey() {
        let file = UrkelFile(
            machineName: "M",
            imports: [ImportDecl(name: "BLE"), ImportDecl(name: "Analytics")],
            states: []
        )
        let ctx = file.templateContext
        let imports = ctx["imports"] as? [[String: Any]] ?? []
        let names = imports.compactMap { $0["name"] as? String }
        #expect(names.contains("BLE"))
        #expect(names.contains("Analytics"))
    }

    @Test("composedMachines mirrors imports with typeName and isLast")
    func composedMachinesKey() {
        let file = UrkelFile(
            machineName: "M",
            imports: [ImportDecl(name: "Loader"), ImportDecl(name: "BLE")],
            states: []
        )
        let ctx = file.templateContext
        let composed = ctx["composedMachines"] as? [[String: Any]] ?? []
        #expect(composed.count == 2)
        let last = composed.last
        #expect(last?["isLast"] as? Bool == true)
        let first = composed.first
        #expect(first?["isLast"] as? Bool == false)
    }

    // MARK: states / initParams

    @Test("states key has all simple states")
    func statesKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Idle"), simple(.state, "Running"), simple(.final, "Done")]
        )
        let ctx = file.templateContext
        let states = ctx["states"] as? [[String: Any]] ?? []
        let names = states.compactMap { $0["name"] as? String }
        #expect(names == ["Idle", "Running", "Done"])
    }

    @Test("state has isInitial and isTerminal flags")
    func stateFlags() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Idle"), simple(.final, "Done")]
        )
        let ctx = file.templateContext
        let states = ctx["states"] as? [[String: Any]] ?? []
        let idle = states.first { $0["name"] as? String == "Idle" }
        let done = states.first { $0["name"] as? String == "Done" }
        #expect(idle?["isInitial"] as? Bool == true)
        #expect(idle?["isTerminal"] as? Bool == false)
        #expect(done?["isTerminal"] as? Bool == true)
    }

    @Test("isLast is set only on final state in list")
    func stateIsLast() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "A"), simple(.state, "B"), simple(.final, "C")]
        )
        let ctx = file.templateContext
        let states = ctx["states"] as? [[String: Any]] ?? []
        #expect(states[0]["isLast"] as? Bool == false)
        #expect(states[2]["isLast"] as? Bool == true)
    }

    @Test("state with params has hasParams:true and populated params array")
    func stateParams() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                simple(.`init`, "Idle"),
                simple(.final, "Done", params: [Parameter(label: "result", typeExpr: "String")])
            ]
        )
        let ctx = file.templateContext
        let states = ctx["states"] as? [[String: Any]] ?? []
        let done = states.first { $0["name"] as? String == "Done" }
        #expect(done?["hasParams"] as? Bool == true)
        let params = done?["params"] as? [[String: Any]] ?? []
        #expect(params.first?["name"] as? String == "result")
    }

    @Test("initParams populated from init state parameters")
    func initParamsKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, params: [Parameter(label: "id", typeExpr: "Int")], name: "Idle")),
                simple(.final, "Done")
            ]
        )
        let ctx = file.templateContext
        let initParams = ctx["initParams"] as? [[String: Any]] ?? []
        #expect(initParams.count == 1)
        #expect(initParams[0]["name"] as? String == "id")
        #expect(initParams[0]["type"] as? String == "Int")
    }

    // MARK: transitions / groupedTransitions

    @Test("transitions key contains all transitions")
    func transitionsKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Idle"), simple(.state, "Running"), simple(.final, "Done")],
            transitions: [
                trans(from: "Idle",    event: "start", to: "Running"),
                trans(from: "Running", event: "stop",  to: "Done"),
            ]
        )
        let ctx = file.templateContext
        let transitions = ctx["transitions"] as? [[String: Any]] ?? []
        #expect(transitions.count == 2)
        #expect(transitions[0]["event"] as? String == "start")
        #expect(transitions[1]["event"] as? String == "stop")
    }

    @Test("timer transition has isTimer:true and event:'after'")
    func timerTransitionIsTimer() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Waiting"), simple(.final, "Expired")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Waiting")),
                    event: .timer(TimerDecl(duration: Duration(value: 5, unit: .s))),
                    destination: StateRef("Expired")
                ))
            ]
        )
        let ctx = file.templateContext
        let transitions = ctx["transitions"] as? [[String: Any]] ?? []
        #expect(transitions.first?["isTimer"] as? Bool == true)
        #expect(transitions.first?["event"] as? String == "after")
    }

    @Test("always transition has event:'always' and isTimer:false")
    func alwaysTransitionEvent() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("A")),
                    event: .always,
                    destination: StateRef("B")
                ))
            ]
        )
        let ctx = file.templateContext
        let transitions = ctx["transitions"] as? [[String: Any]] ?? []
        #expect(transitions.first?["event"] as? String == "always")
        #expect(transitions.first?["isTimer"] as? Bool == false)
    }

    @Test("groupedTransitions groups by source state")
    func groupedTransitions() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Idle"), simple(.state, "Running"), simple(.final, "Done")],
            transitions: [
                trans(from: "Idle",    event: "start",  to: "Running"),
                trans(from: "Idle",    event: "skip",   to: "Done"),
                trans(from: "Running", event: "stop",   to: "Done"),
            ]
        )
        let ctx = file.templateContext
        let groups = ctx["groupedTransitions"] as? [[String: Any]] ?? []
        #expect(groups.count == 2)
        let idleGroup = groups.first { ($0["sourceStateTypeName"] as? String)?.lowercased() == "idle" }
        let idleTransitions = idleGroup?["transitions"] as? [[String: Any]] ?? []
        #expect(idleTransitions.count == 2)
    }

    // MARK: guards / actions / outputEvents

    @Test("guards key collects unique guard names from all transitions")
    func guardsKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                trans(from: "A", event: "go",  to: "B", guard: .named("isReady")),
                trans(from: "A", event: "go2", to: "B", guard: .named("isReady")), // duplicate
                trans(from: "A", event: "go3", to: "B", guard: .negated("isDone")),
            ]
        )
        let ctx = file.templateContext
        let guards = ctx["guards"] as? [String] ?? []
        #expect(guards.count == 2)
        #expect(guards.contains("isReady"))
        #expect(guards.contains("isDone"))
    }

    @Test("guards key excludes 'else' guard")
    func guardsKeyExcludesElse() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                trans(from: "A", event: "go", to: "B", guard: .else)
            ]
        )
        let ctx = file.templateContext
        let guards = ctx["guards"] as? [String] ?? []
        #expect(guards.isEmpty)
    }

    @Test("actions key collects unique action names from transitions and hooks")
    func actionsKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "A"), simple(.state, "B"), simple(.final, "C")],
            entryExitHooks: [EntryExitDecl(hook: .entry, state: StateRef("B"), actions: ["logEntry"])],
            transitions: [
                trans(from: "A", event: "go", to: "B", action: ActionClause(actions: ["trackEvent", "logEntry"])),
                trans(from: "B", event: "done", to: "C"),
            ]
        )
        let ctx = file.templateContext
        let actions = ctx["actions"] as? [String] ?? []
        #expect(actions.contains("trackEvent"))
        #expect(actions.contains("logEntry"))
        // logEntry appears in both hook and transition — should be deduplicated
        #expect(actions.filter { $0 == "logEntry" }.count == 1)
    }

    @Test("outputEvents contains internal arrow transitions without action")
    func outputEventsKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Active"), simple(.final, "Done")],
            transitions: [
                // Output event: internal arrow, no action
                .transition(TransitionStmt(
                    source: .state(StateRef("Active")),
                    arrow: .`internal`,
                    event: .event(EventDecl(name: "didUpdate")),
                    destination: StateRef("Active")
                )),
                trans(from: "Active", event: "stop", to: "Done"),
            ]
        )
        let ctx = file.templateContext
        let outputEvents = ctx["outputEvents"] as? [[String: Any]] ?? []
        #expect(outputEvents.count == 1)
        #expect(outputEvents[0]["event"] as? String == "didUpdate")
    }

    @Test("spawnedMachine key present for fork transitions")
    func spawnedMachineKey() {
        let file = UrkelFile(
            machineName: "M",
            imports: [ImportDecl(name: "Sub")],
            states: [simple(.`init`, "Idle"), simple(.final, "Done")],
            transitions: [
                trans(from: "Idle", event: "go", to: "Done",
                      fork: ForkClause(machine: "Sub", bindings: []))
            ]
        )
        let ctx = file.templateContext
        let transitions = ctx["transitions"] as? [[String: Any]] ?? []
        #expect(transitions.first?["spawnedMachine"] as? String == "Sub")
    }

    @Test("transition guard row has negated flag")
    func transitionGuardNegatedFlag() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                trans(from: "A", event: "go", to: "B", guard: .negated("isReady"))
            ]
        )
        let ctx = file.templateContext
        let transitions = ctx["transitions"] as? [[String: Any]] ?? []
        let guards = transitions.first?["guards"] as? [[String: Any]] ?? []
        #expect(guards.first?["negated"] as? Bool == true)
        #expect(guards.first?["name"] as? String == "isReady")
    }

    @Test("transition isInternal flag set for internal arrow")
    func transitionIsInternal() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Active"), simple(.final, "Done")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Active")),
                    arrow: .`internal`,
                    event: .event(EventDecl(name: "ping")),
                    destination: StateRef("Active")
                )),
                trans(from: "Active", event: "stop", to: "Done"),
            ]
        )
        let ctx = file.templateContext
        let transitions = ctx["transitions"] as? [[String: Any]] ?? []
        let ping = transitions.first { $0["event"] as? String == "ping" }
        #expect(ping?["isInternal"] as? Bool == true)
    }

    // MARK: initialState / initialStateTypeName

    @Test("initialState key matches init state name")
    func initialStateKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "Idle"), simple(.final, "Done")]
        )
        let ctx = file.templateContext
        #expect(ctx["initialState"] as? String == "Idle")
    }

    @Test("initialStateTypeName is PascalCase version of init state name")
    func initialStateTypeNameKey() {
        let file = UrkelFile(
            machineName: "M",
            states: [simple(.`init`, "idle-state"), simple(.final, "Done")]
        )
        let ctx = file.templateContext
        let tn = ctx["initialStateTypeName"] as? String ?? ""
        #expect(tn.first?.isUppercase == true)
    }
}

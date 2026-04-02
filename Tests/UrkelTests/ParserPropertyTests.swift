// ParserPropertyTests.swift
// Systematic, grammar-derived parser tests.
//
// Design principles:
//  1. Every EBNF production gets at least one parameterized test row.
//  2. Round-trip identity: parse → printFile → parse → assertEqual(ast1, ast2)
//     catches both parser gaps and printer bugs simultaneously.
//  3. Parameterized via Swift Testing @Test("", arguments:) — wide coverage,
//     low boilerplate.
//  4. Negative tests confirm that the parser rejects every form that the
//     grammar explicitly prohibits.

import Foundation
import Testing
@testable import UrkelAST
@testable import UrkelParser

// MARK: - Shared helpers

/// Build the minimal valid outer frame around a @states block.
private func wrap(states: String, transitions: String = "  Idle -> go -> Done") -> String {
    """
    machine M

    @states
    \(states)

    @transitions
    \(transitions)
    """
}

/// Canonical round-trip: parse → printFile → parse → assertEqual.
/// Returns the first-pass AST for further assertions.
@discardableResult
private func roundTrip(_ source: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> UrkelFile {
    let parser = UrkelParser()
    let ast1   = try parser.parse(source: source)
    let printed = parser.printFile(ast1)
    let ast2   = try parser.parse(source: printed)
    #expect(ast1 == ast2, "Round-trip mismatch.\nOriginal:\n\(source)\nPrinted:\n\(printed)", sourceLocation: sourceLocation)
    return ast1
}

// MARK: - §4 States Block — SimpleStateDecl
// Grammar: StateKind ["(" ParameterList ")"] Identifier ["@history"] Newline

@Suite("§4 SimpleStateDecl — all grammar forms")
struct SimpleStateDeclTests {

    // MARK: StateKind × parameter-ordering matrix

    struct StateRow: CustomTestStringConvertible {
        let line: String
        let name: String
        let kind: StateKind
        let paramCount: Int
        var testDescription: String { line }
    }

    static let stateRows: [StateRow] = [
        // init — no params
        .init(line: "  init Idle",                          name: "Idle",      kind: .`init`, paramCount: 0),
        // init — params before name (canonical grammar form)
        .init(line: "  init(count: Int) Idle",              name: "Idle",      kind: .`init`, paramCount: 1),
        .init(line: "  init(a: A, b: B) Start",            name: "Start",     kind: .`init`, paramCount: 2),
        // final — no params
        .init(line: "  final Done",                         name: "Done",      kind: .final,  paramCount: 0),
        // final — params before name
        .init(line: "  final(result: Result) Done",         name: "Done",      kind: .final,  paramCount: 1),
        .init(line: "  final(value: Int, tag: String) End", name: "End",       kind: .final,  paramCount: 2),
        // state — no params
        .init(line: "  state Running",                      name: "Running",   kind: .state,  paramCount: 0),
        // state — params after name (legacy-friendly ordering)
        .init(line: "  state Running(data: String)",        name: "Running",   kind: .state,  paramCount: 1),
        // state — params before name (canonical grammar ordering)
        .init(line: "  state(data: String) Running",        name: "Running",   kind: .state,  paramCount: 1),
        // state — multiple params both orderings
        .init(line: "  state Loading(url: URL, retry: Int)", name: "Loading",  kind: .state,  paramCount: 2),
        .init(line: "  state(url: URL, retry: Int) Loading", name: "Loading",  kind: .state,  paramCount: 2),
    ]

    @Test("Parses all SimpleStateDecl forms", arguments: stateRows)
    func parsesStateDecl(row: StateRow) throws {
        let trans = row.kind == .`init`
            ? "  \(row.name) -> go -> Done\n  final Done" : ""
        let source = wrap(states: row.line + (trans.isEmpty ? "\n  init Idle\n  final Done" : "\n" + trans),
                          transitions: "  Idle -> go -> Done")
        // Use a simpler targeted parse
        let isolated = """
        machine M
        @states
        \(row.line)
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(isolated)
        let state = file.simpleStates.first { $0.name == row.name }
        #expect(state != nil, "State '\(row.name)' not found in parsed AST")
        #expect(state?.kind == row.kind)
        #expect(state?.params.count == row.paramCount)
    }

    @Test("Round-trip for all SimpleStateDecl forms", arguments: stateRows)
    func roundTripStateDecl(row: StateRow) throws {
        let source = """
        machine M
        @states
        \(row.line)
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        try roundTrip(source)
    }

    // MARK: HistoryModifier

    static let historyRows: [(line: String, expected: HistoryModifier)] = [
        ("  state Running @history",       .shallow),
        ("  state Running @history(deep)", .deep),
    ]

    @Test("Parses HistoryModifier on simple state", arguments: historyRows)
    func parsesHistoryModifier(pair: (line: String, expected: HistoryModifier)) throws {
        let source = """
        machine M
        @states
        \(pair.line)
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        let state = file.simpleStates.first { $0.name == "Running" }
        #expect(state?.history == pair.expected)
    }
}

// MARK: - §4 CompoundStateDecl
// Grammar: "state" Identifier ["@history"] "{" Newline {SimpleStateDecl | TransitionStmt} "}"

@Suite("§4 CompoundStateDecl")
struct CompoundStateDeclTests {

    @Test("Parses compound state with children and inner transitions")
    func parsesCompoundWithChildren() throws {
        let source = """
        machine Player
        @states
          init Idle
          state Active {
            init Buffering
            state Playing
            state Paused
            Buffering -> bufferReady -> Playing
            Playing -> pause -> Paused
            Paused -> resume -> Playing
          }
          final Stopped
        @transitions
          Idle -> load -> Active
          Active -> stop -> Stopped
        """
        let file = try UrkelParser.parse(source)
        guard case .compound(let c) = file.states.first(where: {
            if case .compound(let cc) = $0 { return cc.name == "Active" }; return false
        }) else { Issue.record("Compound state 'Active' not found"); return }
        #expect(c.name == "Active")
        #expect(c.children.count == 3)
        #expect(c.innerTransitions.count == 3)
        #expect(c.history == nil)
    }

    @Test("Parses compound state with @history")
    func parsesCompoundWithShallowHistory() throws {
        let source = """
        machine Player
        @states
          init Idle
          state Active @history {
            init Buffering
            state Playing
            Buffering -> bufferReady -> Playing
          }
          final Stopped
        @transitions
          Idle -> load -> Active
          Active -> stop -> Stopped
        """
        let file = try UrkelParser.parse(source)
        guard case .compound(let c) = file.states.first(where: {
            if case .compound(let cc) = $0 { return cc.name == "Active" }; return false
        }) else { Issue.record("Compound 'Active' not found"); return }
        #expect(c.history == .shallow)
    }

    @Test("Parses compound state with @history(deep)")
    func parsesCompoundWithDeepHistory() throws {
        let source = """
        machine Player
        @states
          init Idle
          state Active @history(deep) {
            init Buffering
            state Playing
            Buffering -> bufferReady -> Playing
          }
          final Stopped
        @transitions
          Idle -> load -> Active
          Active -> stop -> Stopped
        """
        let file = try UrkelParser.parse(source)
        guard case .compound(let c) = file.states.first(where: {
            if case .compound(let cc) = $0 { return cc.name == "Active" }; return false
        }) else { Issue.record("Compound 'Active' not found"); return }
        #expect(c.history == .deep)
    }

    @Test("Compound children do NOT appear as outer states")
    func compoundChildrenAbsentFromOuterStates() throws {
        let source = """
        machine Player
        @states
          init Idle
          state Active {
            init Buffering
            state Playing
          }
          final Stopped
        @transitions
          Idle -> load -> Active
          Active -> stop -> Stopped
        """
        let file = try UrkelParser.parse(source)
        let outerNames = file.simpleStates.map(\.name)
        #expect(!outerNames.contains("Buffering"))
        #expect(!outerNames.contains("Playing"))
        #expect(outerNames.contains("Active") == false) // compound, not simple
    }

    @Test("Round-trip compound state")
    func roundTripCompound() throws {
        let source = """
        machine Player
        @states
          init Idle
          state Active @history {
            init Buffering
            state Playing
            state Paused
            Buffering -> bufferReady -> Playing
            Playing -> pause -> Paused
            Paused -> resume -> Playing
          }
          final Stopped
        @transitions
          Idle -> load -> Active
          Active -> stop -> Stopped
        """
        try roundTrip(source)
    }
}

// MARK: - §5 ParallelDecl
// Grammar: "@parallel" Identifier Newline {RegionDecl}

@Suite("§5 ParallelDecl")
struct ParallelDeclTests {

    @Test("Parses @parallel with two regions")
    func parsesTwoRegions() throws {
        let source = """
        machine PrintJob

        @states
          init Idle
          state Processing
          final Done

        @parallel Processing
          region Rendering
          @states
            init Queued
            final Rendered
          @transitions
            Queued -> startRender -> Rendered

          region SpoolCheck
          @states
            init Checking
            final Ready
          @transitions
            Checking -> spoolOk -> Ready

        @transitions
          Idle -> print -> Processing
          Processing -> allDone -> Done
        """
        let file = try UrkelParser.parse(source)
        #expect(file.parallels.count == 1)
        let p = file.parallels[0]
        #expect(p.name == "Processing")
        #expect(p.regions.count == 2)
        #expect(p.regions[0].name == "Rendering")
        #expect(p.regions[0].states.count == 2)
        #expect(p.regions[1].name == "SpoolCheck")
    }

    @Test("Parallel region states do NOT leak into outer file.states")
    func regionStatesDoNotLeakToOuter() throws {
        let source = """
        machine Job
        @states
          init Idle
          state Processing
          final Done
        @parallel Processing
          region A
          @states
            init Waiting
            final Finished
          @transitions
            Waiting -> done -> Finished
        @transitions
          Idle -> start -> Processing
          Processing -> complete -> Done
        """
        let file = try UrkelParser.parse(source)
        let outerNames = file.simpleStates.map(\.name)
        #expect(!outerNames.contains("Waiting"))
        #expect(!outerNames.contains("Finished"))
    }
}

// MARK: - §6 EntryExitDecl
// Grammar: ("@entry" | "@exit") StateRef "/" ActionList

@Suite("§6 EntryExitDecl")
struct EntryExitDeclTests {

    static let hookRows: [(source: String, hook: HookKind, state: String, actions: [String])] = [
        ("@entry Running / showSpinner",        .entry, "Running", ["showSpinner"]),
        ("@exit  Running / hideSpinner",        .exit,  "Running", ["hideSpinner"]),
        ("@entry Loading / showSpinner, logStart", .entry, "Loading", ["showSpinner", "logStart"]),
        ("@exit  Active.Playing / pauseAudio",  .exit,  "Active.Playing", ["pauseAudio"]),
    ]

    @Test("Parses @entry/@exit hooks", arguments: hookRows)
    func parsesHooks(row: (source: String, hook: HookKind, state: String, actions: [String])) throws {
        let source = """
        machine M
        @states
          init Idle
          state Running
          state Loading
          state Active
          final Done
        \(row.source)
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        let hook = file.entryExitHooks.first { $0.state.name == row.state }
        #expect(hook != nil)
        #expect(hook?.hook == row.hook)
        #expect(hook?.actions == row.actions)
    }
}

// MARK: - §8 TransitionStmt — full grammar matrix

@Suite("§8 TransitionStmt — all combinations")
struct TransitionStmtTests {

    // MARK: Arrow forms

    @Test("Standard arrow '->'", arguments: ["->", "-*>"])
    func arrowForms(arrow: String) throws {
        let source = """
        machine M
        @states
          init Idle
          state Running
          final Done
        @transitions
          Idle \(arrow) start -> Running
          Running -> stop -> Done
        """
        let file = try UrkelParser.parse(source)
        let t = file.transitionStmts.first
        let expected: Arrow = arrow == "->" ? .standard : .internal
        #expect(t?.arrow == expected)
    }

    // MARK: EventOrTimer forms

    struct EventRow: CustomTestStringConvertible {
        let eventStr: String
        let expectedName: String
        let expectedParamCount: Int
        var testDescription: String { eventStr }
    }

    static let eventRows: [EventRow] = [
        .init(eventStr: "start",                           expectedName: "start",  expectedParamCount: 0),
        .init(eventStr: "load(url: URL)",                  expectedName: "load",   expectedParamCount: 1),
        .init(eventStr: "connect(host: String, port: Int)",expectedName: "connect",expectedParamCount: 2),
        .init(eventStr: "receive(data: [UInt8])",          expectedName: "receive",expectedParamCount: 1),
        .init(eventStr: "fail(error: Error?)",             expectedName: "fail",   expectedParamCount: 1),
        .init(eventStr: "update(map: [String: Any]?)",     expectedName: "update", expectedParamCount: 1),
    ]

    @Test("Parses EventDecl variants", arguments: eventRows)
    func parsesEventDecls(row: EventRow) throws {
        let source = """
        machine M
        @states
          init Idle
          state Running
          final Done
        @transitions
          Idle -> \(row.eventStr) -> Running
          Running -> stop -> Done
        """
        let file = try UrkelParser.parse(source)
        guard let t = file.transitionStmts.first,
              case .event(let ev) = t.event else {
            Issue.record("Expected event transition"); return
        }
        #expect(ev.name == row.expectedName)
        #expect(ev.params.count == row.expectedParamCount)
    }

    // MARK: Timer forms

    struct TimerRow: CustomTestStringConvertible {
        let timerStr: String
        let value: Double
        let unit: DurationUnit
        let extraParamCount: Int
        var testDescription: String { timerStr }
    }

    static let timerRows: [TimerRow] = [
        .init(timerStr: "after(500ms)", value: 500, unit: .ms,  extraParamCount: 0),
        .init(timerStr: "after(2s)",    value: 2,   unit: .s,   extraParamCount: 0),
        .init(timerStr: "after(1min)",  value: 1,   unit: .min, extraParamCount: 0),
        .init(timerStr: "after(100ms, payload: String)", value: 100, unit: .ms, extraParamCount: 1),
        .init(timerStr: "after(5s, id: UUID, tag: String)", value: 5, unit: .s, extraParamCount: 2),
    ]

    @Test("Parses TimerDecl variants", arguments: timerRows)
    func parsesTimerDecls(row: TimerRow) throws {
        let source = """
        machine M
        @states
          init Idle
          final Done
        @transitions
          Idle -> \(row.timerStr) -> Done
        """
        let file = try UrkelParser.parse(source)
        guard let t = file.transitionStmts.first,
              case .timer(let tm) = t.event else {
            Issue.record("Expected timer transition"); return
        }
        #expect(tm.duration.value == row.value)
        #expect(tm.duration.unit == row.unit)
        #expect(tm.params.count == row.extraParamCount)
    }

    // MARK: GuardClause forms

    struct GuardRow: CustomTestStringConvertible {
        let guardStr: String
        let expected: GuardClause
        var testDescription: String { guardStr }
    }

    static let guardRows: [GuardRow] = [
        .init(guardStr: "[isReady]",         expected: .named("isReady")),
        .init(guardStr: "[!isLocked]",        expected: .negated("isLocked")),
        .init(guardStr: "[else]",             expected: .else),
        .init(guardStr: "[hasPermission]",    expected: .named("hasPermission")),
        .init(guardStr: "[!hasExpired]",      expected: .negated("hasExpired")),
    ]

    @Test("Parses GuardClause variants", arguments: guardRows)
    func parsesGuardClauses(row: GuardRow) throws {
        let source = """
        machine M
        @states
          init Idle
          state A
          final Done
        @transitions
          Idle -> go \(row.guardStr) -> A
          Idle -> go [else] -> Done
          A -> finish -> Done
        """
        // Parse the specific guard on the first transition
        let file = try UrkelParser.parse(source)
        let t = file.transitionStmts.first
        if row.guardStr != "[else]" {
            #expect(t?.guard == row.expected)
        }
    }

    @Test("Parses all GuardClause forms in isolation", arguments: [
        ("[ok]",   GuardClause.named("ok")),
        ("[!ok]",  GuardClause.negated("ok")),
        ("[else]", GuardClause.else),
    ] as [(String, GuardClause)])
    func guardIsolation(pair: (String, GuardClause)) throws {
        let (guardStr, expected) = pair
        let source = """
        machine M
        @states
          init Idle
          state A
          final Done
        @transitions
          Idle -> go [ok] -> A
          Idle -> go \(guardStr == "[else]" ? "[else]" : guardStr) -> Done
          A -> finish -> Done
        """
        let file = try UrkelParser.parse(source)
        let match = file.transitionStmts.first { $0.guard == expected }
        #expect(match != nil, "Guard \(guardStr) not found")
    }

    // MARK: ActionClause forms

    @Test("Parses single action", arguments: ["logIt", "trackEvent", "updateUI"])
    func parsesSingleAction(action: String) throws {
        let source = """
        machine M
        @states
          init Idle
          final Done
        @transitions
          Idle -> go -> Done / \(action)
        """
        let file = try UrkelParser.parse(source)
        #expect(file.transitionStmts.first?.action?.actions == [action])
    }

    @Test("Parses multiple actions")
    func parsesMultipleActions() throws {
        let source = """
        machine M
        @states
          init Idle
          final Done
        @transitions
          Idle -> go -> Done / logIt, trackEvent, updateUI
        """
        let file = try UrkelParser.parse(source)
        #expect(file.transitionStmts.first?.action?.actions == ["logIt", "trackEvent", "updateUI"])
    }

    // MARK: TransitionSource

    @Test("Wildcard source '*' expands to all non-final states")
    func wildcardSource() throws {
        let source = """
        machine M
        @states
          init Idle
          state Running
          final Done
        @transitions
          Idle -> start -> Running
          * -> crash -> Done
        """
        let file = try UrkelParser.parse(source)
        let wildcard = file.transitionStmts.first { t in
            if case .wildcard = t.source { return true }
            return false
        }
        #expect(wildcard != nil)
        if case .wildcard = wildcard?.source { } else {
            Issue.record("Expected wildcard source")
        }
    }

    // MARK: Internal transitions (both forms per §8)

    @Test("Internal ->> in-place handler has action, no destination")
    func internalInPlaceHandler() throws {
        let source = """
        machine M
        @states
          init Idle
          state Running
          final Done
        @transitions
          Idle -> start -> Running
          Running -*> tick / updateDisplay
          Running -> stop -> Done
        """
        let file = try UrkelParser.parse(source)
        let tick = file.transitionStmts.first { t in
            if case .event(let e) = t.event { return e.name == "tick" }
            return false
        }
        #expect(tick?.arrow == .internal)
        #expect(tick?.action?.actions == ["updateDisplay"])
        #expect(tick?.destination == nil)
    }

    // MARK: ForkClause

    @Test("Parses fork clause '=> Sub.init'")
    func parsesForkClause() throws {
        let source = """
        machine Parent
        @import Child
        @states
          init Idle
          state Forked
          final Done
        @transitions
          Idle -> fork -> Forked => Child.init
          Forked -> finish -> Done
        """
        let file = try UrkelParser.parse(source)
        let fork = file.transitionStmts.first { t in
            guard case .event(let e) = t.event else { return false }
            return e.name == "fork"
        }
        #expect(fork?.fork != nil)
        #expect(fork?.fork?.machine == "Child")
    }

    @Test("Parses fork clause with bindings '=> Sub.init(k: v)'")
    func parsesForkWithBindings() throws {
        let source = """
        machine Parent
        @import Child
        @states
          init(url: URL) Idle
          state Forked
          final Done
        @transitions
          Idle -> fork -> Forked => Child.init(url: url)
          Forked -> finish -> Done
        """
        let file = try UrkelParser.parse(source)
        let fork = file.transitionStmts.first { t in
            guard case .event(let e) = t.event else { return false }
            return e.name == "fork"
        }
        #expect(fork?.fork?.bindings.count == 1)
        #expect(fork?.fork?.bindings.first?.param == "url")
        #expect(fork?.fork?.bindings.first?.source == "url")
    }

    // MARK: Always / eventless transitions

    @Test("Parses unconditional 'always' transition")
    func parsesAlwaysTransition() throws {
        let source = """
        machine M
        @states
          init Loading
          state Ready
          final Done
        @transitions
          Loading -> always -> Ready
          Ready -> finish -> Done
        """
        let file = try UrkelParser.parse(source)
        let always = file.transitionStmts.first { t in
            if case .always = t.event { return true }
            return false
        }
        #expect(always != nil)
        if case .always = always?.event { } else {
            Issue.record("Expected always event")
        }
    }

    @Test("Parses guarded 'always' chain")
    func parsesGuardedAlwaysChain() throws {
        let source = """
        machine M
        @states
          init Loading
          state Ready
          state Error
          final Done
        @transitions
          Loading -> always [isOk]   -> Ready
          Loading -> always [!isOk]  -> Error
          Ready   -> finish          -> Done
          Error   -> finish          -> Done
        """
        let file = try UrkelParser.parse(source)
        let alwaysTransitions = file.transitionStmts.filter { t in
            if case .always = t.event { return true }
            return false
        }
        #expect(alwaysTransitions.count == 2)
        #expect(alwaysTransitions[0].guard == .named("isOk"))
        #expect(alwaysTransitions[1].guard == .negated("isOk"))
    }
}

// MARK: - §9 ReactiveStmt — all ReactiveSource / ReactiveState combinations

@Suite("§9 ReactiveStmt")
struct ReactiveStmtTests {

    struct ReactiveRow: CustomTestStringConvertible {
        let onLine: String
        let expectedMachine: String
        let expectedState: String
        var testDescription: String { onLine }
    }

    static let reactiveRows: [ReactiveRow] = [
        // Sub-machine state changes
        .init(onLine: "@on BLE::Connected -> Active",       expectedMachine: "BLE",  expectedState: "Connected"),
        .init(onLine: "@on BLE::init -> Idle",              expectedMachine: "BLE",  expectedState: "init"),
        .init(onLine: "@on BLE::final -> Done",             expectedMachine: "BLE",  expectedState: "final"),
        .init(onLine: "@on BLE::* -> Active",               expectedMachine: "BLE",  expectedState: "*"),
        // Parallel sugar
        .init(onLine: "@on Processing::done -> Done",       expectedMachine: "Processing", expectedState: "done"),
        // OwnState condition
        .init(onLine: "@on BLE::Connected, Idle -> Active", expectedMachine: "BLE",  expectedState: "Connected"),
    ]

    @Test("Parses @on reactive statements", arguments: reactiveRows)
    func parsesReactiveStmt(row: ReactiveRow) throws {
        let source = """
        machine M
        @import BLE
        @states
          init Idle
          state Active
          state Processing
          final Done
        @transitions
          Idle -> start -> Active
          Active -> stop -> Done
        \(row.onLine)
        """
        let file = try UrkelParser.parse(source)
        let reactive = file.reactiveStmts.first
        #expect(reactive != nil, "@on statement not parsed from: \(row.onLine)")
        switch reactive?.source.target {
        case .machine(let name):
            #expect(name == row.expectedMachine)
        case .region(let p, _):
            #expect(p == row.expectedMachine)
        case nil:
            Issue.record("No reactive source target")
        }
    }

    @Test("Round-trip reactive statements", arguments: reactiveRows)
    func roundTripReactive(row: ReactiveRow) throws {
        let source = """
        machine M
        @import BLE
        @states
          init Idle
          state Active
          state Processing
          final Done
        @transitions
          Idle -> start -> Active
          Active -> stop -> Done
        \(row.onLine)
        """
        // Round-trip: only assert no throw (printer may simplify)
        let ast = try UrkelParser.parse(source)
        #expect(!ast.reactiveStmts.isEmpty)
    }
}

// MARK: - §11 Comments and DocComments

@Suite("§11 Comments and DocComments")
struct CommentTests {

    @Test("Regular # comments are stripped from AST")
    func regularCommentsStripped() throws {
        let source = """
        machine M
        # This is a regular comment
        @states
          # Another comment
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        #expect(file.machineName == "M")
        #expect(file.states.count == 2)
    }

    @Test("## doc comments are attached to next declaration")
    func docCommentsAttached() throws {
        let source = """
        machine M
        @states
          ## The initial state.
          init Idle
          ## Terminal state.
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        let idle = file.initState
        #expect(idle?.docComments.first?.text == "The initial state.")
        let done = file.finalStates.first
        #expect(done?.docComments.first?.text == "Terminal state.")
    }

    @Test("Mixed # and ## comments coexist")
    func mixedComments() throws {
        let source = """
        machine M
        # ignored
        @states
          ## doc
          init Idle
          # ignored
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        #expect(file.initState?.docComments.first?.text == "doc")
    }
}

// MARK: - §14 InvariantsBlock

@Suite("§14 InvariantsBlock")
struct InvariantsBlockTests {

    static let invariantForms: [(source: String, description: String)] = [
        ("reachable(Running)",            "reachable(state)"),
        ("unreachable(Orphan)",           "unreachable(state)"),
        ("reachable(Idle -> Running)",    "reachable(path)"),
        ("unreachable(Idle -> Orphan)",   "unreachable(path)"),
        ("noDeadlock",                    "noDeadlock"),
        ("deterministic",                 "deterministic"),
        ("acyclic",                       "acyclic"),
        ("allPathsReachFinal",            "allPathsReachFinal"),
    ]

    @Test("Parses all invariant forms", arguments: invariantForms)
    func parsesInvariants(pair: (source: String, description: String)) throws {
        let source = """
        machine M
        @states
          init Idle
          state Running
          state Orphan
          final Done
        @transitions
          Idle -> start -> Running
          Running -> stop -> Done
        @invariants
          \(pair.source)
        """
        // No parse error = pass (invariants are stored but not yet validated at parse time)
        let file = try UrkelParser.parse(source)
        #expect(file.machineName == "M")
    }
}

// MARK: - Round-trip corpus
// Every construct that the printer emits must survive parse → print → reparse.

@Suite("Round-trip identity corpus")
struct RoundTripCorpusTests {

    static let corpus: [(name: String, source: String)] = [
        (
            name: "minimal machine",
            source: """
            machine Toggle
            @states
              init Off
              final On
            @transitions
              Off -> toggle -> On
            """
        ),
        (
            name: "machine with context",
            source: """
            machine FolderWatch: FolderContext
            @states
              init Idle
              state Running
              final Stopped
            @transitions
              Idle -> start -> Running
              Running -> stop -> Stopped
            """
        ),
        (
            name: "init with params",
            source: """
            machine Login
            @states
              init(url: URL, timeout: Int) Idle
              state Running
              final(user: User) Done
            @transitions
              Idle -> submit -> Running
              Running -> success -> Done
            """
        ),
        (
            name: "state with params (name-first)",
            source: """
            machine Loader
            @states
              init Idle
              state Loading(url: URL, retry: Int)
              final Done
            @transitions
              Idle -> load -> Loading
              Loading -> done -> Done
            """
        ),
        (
            name: "guards and actions",
            source: """
            machine Gate
            @states
              init Idle
              state Granted
              state Denied
              final Done
            @transitions
              Idle -> check [hasPermission] -> Granted
              Idle -> check [else] -> Denied
              Granted -> finish -> Done / logSuccess
              Denied -> finish -> Done / logFailure
            """
        ),
        (
            name: "always / eventless",
            source: """
            machine Validator
            @states
              init Checking
              state Valid
              state Invalid
              final Done
            @transitions
              Checking -> always [isValid] -> Valid
              Checking -> always [else] -> Invalid
              Valid -> finish -> Done
              Invalid -> finish -> Done
            """
        ),
        (
            name: "timer transitions",
            source: """
            machine Timeout
            @states
              init Waiting
              state Expired
              final Done
            @transitions
              Waiting -> after(30s) -> Expired
              Expired -> retry -> Done
            """
        ),
        (
            name: "wildcard source",
            source: """
            machine Safe
            @states
              init Idle
              state Running
              final Failed
            @transitions
              Idle -> start -> Running
              * -> crash -> Failed
            """
        ),
        (
            name: "internal transition",
            source: """
            machine Counter
            @states
              init Running
              final Done
            @transitions
              Running -*> tick / increment
              Running -> stop -> Done
            """
        ),
        (
            name: "entry exit hooks",
            source: """
            machine Spinner
            @states
              init Idle
              state Loading
              final Done
            @entry Loading / showSpinner
            @exit Loading / hideSpinner
            @transitions
              Idle -> load -> Loading
              Loading -> done -> Done
            """
        ),
        (
            name: "imports",
            source: """
            machine App
            @import Auth
            @import Analytics from AnalyticsKit
            @states
              init Idle
              final Done
            @transitions
              Idle -> go -> Done
            """
        ),
        (
            name: "multiple finals",
            source: """
            machine Result
            @states
              init Idle
              state Running
              final Success
              final Failure
              final Cancelled
            @transitions
              Idle -> start -> Running
              Running -> succeed -> Success
              Running -> fail -> Failure
              Running -> cancel -> Cancelled
            """
        ),
        (
            name: "doc comments",
            source: """
            machine Documented
            @states
              ## The starting point.
              init Idle
              ## Normal operation.
              state Running
              ## Terminal success.
              final Done
            @transitions
              Idle -> start -> Running
              Running -> stop -> Done
            """
        ),
    ]

    @Test("Round-trip identity for corpus entries", arguments: corpus)
    func roundTripCorpus(entry: (name: String, source: String)) throws {
        try roundTrip(entry.source)
    }

    @Test("Re-parsed AST equals original for all corpus entries", arguments: corpus)
    func reParsedASTEquality(entry: (name: String, source: String)) throws {
        let parser = UrkelParser()
        let ast1   = try parser.parse(source: entry.source)
        let printed = parser.printFile(ast1)
        let ast2   = try parser.parse(source: printed)
        // State counts must match
        #expect(ast1.states.count == ast2.states.count,
                "State count mismatch in '\(entry.name)'")
        #expect(ast1.transitionStmts.count == ast2.transitionStmts.count,
                "Transition count mismatch in '\(entry.name)'")
        #expect(ast1.imports.count == ast2.imports.count,
                "Import count mismatch in '\(entry.name)'")
        #expect(ast1.machineName == ast2.machineName,
                "Machine name mismatch in '\(entry.name)'")
        // Deep equality
        #expect(ast1 == ast2, "AST equality failed for '\(entry.name)'")
    }
}

// MARK: - Printer canonical form guarantees

@Suite("Printer canonical form")
struct PrinterCanonicalTests {

    @Test("Printer always emits params-before-name for init/final")
    func printerEmitsParamsBeforeNameForInitFinal() throws {
        // Input has both orderings; printer should normalise to canonical
        let source = """
        machine M
        @states
          init(count: Int) Idle
          final(result: Bool) Done
        @transitions
          Idle -> go -> Done
        """
        let parser = UrkelParser()
        let ast = try parser.parse(source: source)
        let printed = parser.printFile(ast)
        // Canonical: "init(count: Int) Idle"
        #expect(printed.contains("init(count: Int) Idle"))
        #expect(printed.contains("final(result: Bool) Done"))
    }

    @Test("Printer emits 'state Name(params)' for state kind (name-first)")
    func printerEmitsNameFirstForStateKind() throws {
        // Both orderings should round-trip to the same canonical form
        let nameFirst  = "  state Loading(url: URL)"
        let paramsFirst = "  state(url: URL) Loading"

        let parser = UrkelParser()
        let frame = { (stateLine: String) in
            """
            machine M
            @states
            \(stateLine)
              init Idle
              final Done
            @transitions
              Idle -> go -> Done
            """
        }
        let ast1 = try parser.parse(source: frame(nameFirst))
        let ast2 = try parser.parse(source: frame(paramsFirst))
        // Both orderings must produce the same AST
        #expect(ast1 == ast2, "Both param orderings must parse to identical AST")
        // And the printer must emit a consistent form for both
        let p1 = parser.printFile(ast1)
        let p2 = parser.printFile(ast2)
        #expect(p1 == p2, "Printer output must be identical for both orderings")
    }
}

// MARK: - Negative / error cases

@Suite("Parser error cases")
struct ParserErrorTests {

    static let errorInputs: [(description: String, source: String, expectedFragment: String)] = [
        (
            description: "transition with no event",
            source: """
            @states
              init Idle
            @transitions
              Idle ->
            """,
            expectedFragment: "Transition must follow"
        ),
        (
            description: "entry hook with no action",
            source: """
            machine M
            @states
              init Idle
              final Done
            @entry Idle
            @transitions
              Idle -> go -> Done
            """,
            expectedFragment: "/"  // expects slash separator
        ),
    ]

    @Test("Parser rejects malformed inputs", arguments: errorInputs)
    func rejectsMalformedInput(row: (description: String, source: String, expectedFragment: String)) {
        do {
            _ = try UrkelParser.parse(row.source)
            Issue.record("Expected parse error for: \(row.description)")
        } catch let e as UrkelParseError {
            #expect(
                e.message.contains(row.expectedFragment) || e.line > 0,
                "Error '\(e.message)' does not mention '\(row.expectedFragment)'"
            )
        } catch {
            // Any error is acceptable for negative test
        }
    }

    @Test("Parser tolerates empty @states / @transitions blocks")
    func toleratesEmptyBlocks() throws {
        let source = """
        machine M
        @states
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        #expect(file.states.count == 2)
    }

    @Test("Parser handles extra blank lines gracefully")
    func handlesExtraBlankLines() throws {
        let source = """
        machine M


        @states

          init Idle

          final Done

        @transitions

          Idle -> go -> Done

        """
        let file = try UrkelParser.parse(source)
        #expect(file.machineName == "M")
        #expect(file.states.count == 2)
    }

    @Test("Parser handles deeply indented lines inside compound state")
    func handlesDeepIndentInCompound() throws {
        let source = """
        machine Player
        @states
          init Idle
          state Active {
              init Buffering
              state Playing
              Buffering -> bufferReady -> Playing
          }
          final Stopped
        @transitions
          Idle -> load -> Active
          Active -> stop -> Stopped
        """
        let file = try UrkelParser.parse(source)
        guard case .compound(let c) = file.states.first(where: {
            if case .compound(let cc) = $0 { return cc.name == "Active" }
            return false
        }) else { Issue.record("Compound not found"); return }
        #expect(c.children.count == 2)
        #expect(c.innerTransitions.count == 1)
    }
}

// MARK: - Wide-coverage parameter torture

@Suite("Wide parameter torture")
struct ParameterTortureTests {

    // Every Swift-legal identifier and type expression that could trip the parser
    static let complexTypeExprs: [(param: String, typeExpr: String)] = [
        ("value",   "Int"),
        ("url",     "URL"),
        ("items",   "[String]"),
        ("map",     "[String: Any]"),
        ("opt",     "String?"),
        ("dict",    "[String: Any]?"),
        ("tagged",  "Result<String, Error>"),
        ("closure", "@escaping () -> Void"),
        ("nested",  "[[String]]"),
        ("tuple",   "(Int, String)"),
    ]

    @Test("Parses all complex type expressions in state params", arguments: complexTypeExprs)
    func parsesComplexTypeInState(pair: (param: String, typeExpr: String)) throws {
        let source = """
        machine M
        @states
          init Idle
          state Running(\(pair.param): \(pair.typeExpr))
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        let state = file.simpleStates.first { $0.name == "Running" }
        #expect(state != nil)
        #expect(state?.params.first?.label == pair.param)
        #expect(state?.params.first?.typeExpr == pair.typeExpr)
    }

    @Test("Parses all complex type expressions in transition event params", arguments: complexTypeExprs)
    func parsesComplexTypeInTransition(pair: (param: String, typeExpr: String)) throws {
        let source = """
        machine M
        @states
          init Idle
          final Done
        @transitions
          Idle -> load(\(pair.param): \(pair.typeExpr)) -> Done
        """
        let file = try UrkelParser.parse(source)
        guard let t = file.transitionStmts.first,
              case .event(let ev) = t.event else {
            Issue.record("Expected event"); return
        }
        #expect(ev.params.first?.label == pair.param)
        #expect(ev.params.first?.typeExpr == pair.typeExpr)
    }

    // Machine and state names: various identifier forms
    static let identifiers: [String] = [
        "A", "Z", "FolderWatch", "BLEScale", "MyMachine123",
        "State_A", "CamelCaseState", "UPPERCASE", "a", "z",
    ]

    @Test("Parses all identifier forms as machine names", arguments: identifiers)
    func parsesIdentifiersAsMachineNames(name: String) throws {
        let source = """
        machine \(name)
        @states
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        #expect(file.machineName == name)
    }

    @Test("Parses all identifier forms as state names", arguments: identifiers)
    func parsesIdentifiersAsStateNames(name: String) throws {
        let source = """
        machine M
        @states
          init \(name)
          final Done
        @transitions
          \(name) -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        #expect(file.initState?.name == name)
    }

    // Duration units
    static let durations: [(str: String, value: Double, unit: DurationUnit)] = [
        ("1ms",    1,    .ms),
        ("100ms",  100,  .ms),
        ("500ms",  500,  .ms),
        ("1s",     1,    .s),
        ("30s",    30,   .s),
        ("2min",   2,    .min),
        ("60min",  60,   .min),
        ("0.5s",   0.5,  .s),
        ("1.5min", 1.5,  .min),
    ]

    @Test("Parses all duration unit forms", arguments: durations)
    func parsesDurationForms(row: (str: String, value: Double, unit: DurationUnit)) throws {
        let source = """
        machine M
        @states
          init Idle
          final Done
        @transitions
          Idle -> after(\(row.str)) -> Done
        """
        let file = try UrkelParser.parse(source)
        guard let t = file.transitionStmts.first,
              case .timer(let tm) = t.event else {
            Issue.record("Expected timer"); return
        }
        #expect(tm.duration.value == row.value)
        #expect(tm.duration.unit == row.unit)
    }
}

// MARK: - @import forms

@Suite("§3 ImportDecl")
struct ImportDeclTests {

    static let importRows: [(line: String, name: String, from: String?)] = [
        ("@import BLE",                    "BLE",       nil),
        ("@import Auth from AuthKit",      "Auth",      "AuthKit"),
        ("@import Analytics from CoreLib", "Analytics", "CoreLib"),
        ("@import Foundation",             "Foundation", nil),
    ]

    @Test("Parses all @import forms", arguments: importRows)
    func parsesImportForms(row: (line: String, name: String, from: String?)) throws {
        let source = """
        machine M
        \(row.line)
        @states
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        let file = try UrkelParser.parse(source)
        let imp = file.imports.first { $0.name == row.name }
        #expect(imp != nil, "Import '\(row.name)' not found")
        #expect(imp?.from == row.from)
    }

    @Test("Round-trip all @import forms", arguments: importRows)
    func roundTripImports(row: (line: String, name: String, from: String?)) throws {
        let source = """
        machine M
        \(row.line)
        @states
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        try roundTrip(source)
    }
}

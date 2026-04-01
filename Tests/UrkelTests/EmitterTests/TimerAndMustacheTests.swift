import Testing
import Foundation
@testable import Urkel

// MARK: - US-5.10 fixture

/// Machine with a timer transition.
func makeTrafficLightFile() -> UrkelFile {
    UrkelFile(
        machineName: "TrafficLight",
        contextType: "TrafficContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, params: [], name: "Red")),
            .simple(SimpleStateDecl(kind: .state,  params: [], name: "Green")),
            .simple(SimpleStateDecl(kind: .final,  params: [], name: "Emergency")),
        ],
        transitions: [
            .transition(TransitionStmt(
                source:      .state(StateRef("Red")),
                event:       .timer(TimerDecl(duration: Duration(value: 30, unit: .s))),
                destination: StateRef("Green"))),
            .transition(TransitionStmt(
                source:      .state(StateRef("Red")),
                event:       .event(EventDecl(name: "emergency")),
                destination: StateRef("Emergency"))),
            .transition(TransitionStmt(
                source:      .state(StateRef("Green")),
                event:       .event(EventDecl(name: "cycle")),
                destination: StateRef("Emergency"))),
        ]
    )
}

// MARK: - US-5.10: Timers

@Suite("US-5.10 — Timers")
struct TimerEmitterTests {

    @Test("_timerTask is declared on machine struct when timers present")
    func timerTaskDeclaredInStruct() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeTrafficLightFile())
        #expect(files.stateMachine.contains("_timerTask"))
        #expect(files.stateMachine.contains("Task<Void, Never>"))
    }

    @Test("_timerTask uses nonisolated(unsafe) for Sendable compliance")
    func timerTaskNonisolatedUnsafe() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeTrafficLightFile())
        #expect(files.stateMachine.contains("nonisolated(unsafe)"))
    }

    @Test("startTimer(onFire:) consuming method generated on timer phase")
    func startTimerMethodGenerated() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeTrafficLightFile())
        #expect(files.stateMachine.contains("func startTimer("))
        #expect(files.stateMachine.contains("onFire"))
    }

    @Test("startTimer uses correct duration from DSL")
    func startTimerUsesCorrectDuration() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeTrafficLightFile())
        #expect(files.stateMachine.contains(".seconds(30)"))
    }

    @Test("toGreen() consuming method generated for timer destination")
    func timerFiredMethodGenerated() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeTrafficLightFile())
        #expect(files.stateMachine.contains("func toGreen()") || files.stateMachine.contains("toGreen"))
    }

    @Test("timer cancel called in timer-fired method")
    func timerFiredMethodCancelsTimer() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeTrafficLightFile())
        #expect(files.stateMachine.contains("_timerTask?.cancel()"))
    }

    @Test("statesWithTimers only returns states with timer transitions")
    func statesWithTimersFiltersCorrectly() throws {
        let timerStates = SwiftSyntaxEmitter().statesWithTimers(in: makeTrafficLightFile())
        #expect(timerStates.map(\.name).contains("Red"))
        #expect(!timerStates.map(\.name).contains("Green"))
    }

    @Test("machine without timers has no _timerTask")
    func noTimerMachineHasNoTimerTask() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeFolderWatchFile())
        #expect(!files.stateMachine.contains("_timerTask"))
    }

    @Test("timer closure referenced in client")
    func timerClosureInClient() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeTrafficLightFile())
        // client should reference the timer destination closure
        #expect(files.client.contains("timerToGreen") || files.client.contains("_timerTask"))
    }

    @Test("all TrafficLight emitted files parse without errors")
    func trafficLightFilesParseClean() throws {
        let emitter = SwiftSyntaxEmitter()
        let files   = try emitter.emit(file: makeTrafficLightFile())
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

// MARK: - US-5.13: Mustache swift.mustache template

@Suite("US-5.13 — Mustache swift.mustache Template")
struct MustacheSwiftTemplateTests {

    // Load swift.mustache from the source tree relative to the package root
    private var swiftTemplate: String {
        get throws {
            let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let url  = root.appendingPathComponent("Sources/Urkel/Templates/swift.mustache")
            return try String(contentsOf: url, encoding: .utf8)
        }
    }

    @Test("swift.mustache template renders phase namespace")
    func rendersPhaseNamespace() throws {
        let body = try MustacheEmitter().render(file: makeFolderWatchFile(), templateString: swiftTemplate)
        #expect(body.contains("FolderWatchPhase"))
        #expect(body.contains("public enum Idle {}"))
        #expect(body.contains("public enum Running {}"))
    }

    @Test("swift.mustache template renders machine struct")
    func rendersMachineStruct() throws {
        let body = try MustacheEmitter().render(file: makeFolderWatchFile(), templateString: swiftTemplate)
        #expect(body.contains("FolderWatchMachine<Phase>"))
        #expect(body.contains("~Copyable"))
        #expect(body.contains("Sendable"))
    }

    @Test("swift.mustache template renders combined state enum")
    func rendersStateEnum() throws {
        let body = try MustacheEmitter().render(file: makeFolderWatchFile(), templateString: swiftTemplate)
        #expect(body.contains("FolderWatchState: ~Copyable"))
        #expect(body.contains("case idle("))
        #expect(body.contains("case running("))
    }

    @Test("swift.mustache template renders client struct")
    func rendersClientStruct() throws {
        let body = try MustacheEmitter().render(file: makeFolderWatchFile(), templateString: swiftTemplate)
        #expect(body.contains("FolderWatchClient"))
        #expect(body.contains("makeObserver"))
    }

    @Test("swift.mustache template renders noop property")
    func rendersNoop() throws {
        let body = try MustacheEmitter().render(file: makeFolderWatchFile(), templateString: swiftTemplate)
        #expect(body.contains("noop"))
    }

    @Test("swift.mustache renders Dependencies import")
    func rendersDependenciesImport() throws {
        let body = try MustacheEmitter().render(file: makeFolderWatchFile(), templateString: swiftTemplate)
        #expect(body.contains("import Dependencies"))
    }

    @Test("swift.mustache renders transitions grouped by source state")
    func rendersGroupedTransitions() throws {
        let body = try MustacheEmitter().render(file: makeFolderWatchFile(), templateString: swiftTemplate)
        #expect(body.contains("where Phase == FolderWatchPhase.Idle"))
        #expect(body.contains("func start(") || body.contains("func start()"))
    }

    @Test("groupedTransitions context key is populated with source states")
    func groupedTransitionsContextKey() throws {
        let ctx = makeFolderWatchFile().templateContext
        guard let grouped = ctx["groupedTransitions"] as? [[String: Any]] else {
            Issue.record("groupedTransitions is missing or wrong type")
            return
        }
        #expect(!grouped.isEmpty)
        let sources = grouped.compactMap { $0["sourceStateTypeName"] as? String }
        #expect(sources.contains("Idle"))
        #expect(sources.contains("Running"))
    }

    @Test("initialStateTypeName is a non-nil String")
    func initialStateTypeNameIsString() throws {
        let ctx = makeFolderWatchFile().templateContext
        #expect(ctx["initialStateTypeName"] is String)
        #expect((ctx["initialStateTypeName"] as? String) == "Idle")
    }
}

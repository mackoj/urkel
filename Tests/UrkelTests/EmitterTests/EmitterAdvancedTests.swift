import Testing
import Foundation
@testable import Urkel

// MARK: - Fixtures for advanced features

/// Machine with final states that carry output data (US-5.4).
func makeLoginFile() -> UrkelFile {
    UrkelFile(
        machineName: "Login",
        contextType: "LoginContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, params: [], name: "Idle")),
            .simple(SimpleStateDecl(kind: .state,  params: [], name: "Loading")),
            .simple(SimpleStateDecl(kind: .final,
                                    params: [Parameter(label: "user", typeExpr: "User")],
                                    name: "Success")),
            .simple(SimpleStateDecl(kind: .final,
                                    params: [Parameter(label: "error", typeExpr: "AuthError")],
                                    name: "Failure")),
        ],
        transitions: [
            .transition(TransitionStmt(
                source: .state(StateRef("Idle")),
                event:  .event(EventDecl(name: "submit")),
                destination: StateRef("Loading"))),
            .transition(TransitionStmt(
                source: .state(StateRef("Loading")),
                event:  .event(EventDecl(name: "succeed",
                                         params: [Parameter(label: "user", typeExpr: "User")])),
                destination: StateRef("Success"))),
            .transition(TransitionStmt(
                source: .state(StateRef("Loading")),
                event:  .event(EventDecl(name: "fail",
                                         params: [Parameter(label: "error", typeExpr: "AuthError")])),
                destination: StateRef("Failure"))),
        ]
    )
}

/// Machine with a non-final state carrying data (US-5.5).
func makeDataFetchFile() -> UrkelFile {
    UrkelFile(
        machineName: "DataFetch",
        contextType: "DataFetchContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, params: [], name: "Idle")),
            .simple(SimpleStateDecl(kind: .state,  params: [], name: "Loading")),
            .simple(SimpleStateDecl(kind: .state,
                                    params: [Parameter(label: "data", typeExpr: "Data"),
                                             Parameter(label: "source", typeExpr: "URL")],
                                    name: "Loaded")),
            .simple(SimpleStateDecl(kind: .final,  params: [], name: "Done")),
        ],
        transitions: [
            .transition(TransitionStmt(
                source: .state(StateRef("Idle")),
                event:  .event(EventDecl(name: "fetch")),
                destination: StateRef("Loading"))),
            .transition(TransitionStmt(
                source: .state(StateRef("Loading")),
                event:  .event(EventDecl(name: "fetchSuccess",
                                         params: [Parameter(label: "data", typeExpr: "Data"),
                                                  Parameter(label: "source", typeExpr: "URL")])),
                destination: StateRef("Loaded"))),
            .transition(TransitionStmt(
                source: .state(StateRef("Loaded")),
                event:  .event(EventDecl(name: "accept")),
                destination: StateRef("Done"))),
        ]
    )
}

/// Machine with action clauses and entry/exit hooks (US-5.6).
func makePlayerFile() -> UrkelFile {
    UrkelFile(
        machineName: "Player",
        contextType: "PlayerContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
            .simple(SimpleStateDecl(kind: .state,  name: "Playing")),
            .simple(SimpleStateDecl(kind: .final,  name: "Stopped")),
        ],
        entryExitHooks: [
            EntryExitDecl(hook: .entry, state: StateRef("Playing"), actions: ["startAnalytics"]),
            EntryExitDecl(hook: .exit,  state: StateRef("Playing"), actions: ["stopAnalytics"]),
        ],
        transitions: [
            .transition(TransitionStmt(
                source: .state(StateRef("Idle")),
                event:  .event(EventDecl(name: "play")),
                destination: StateRef("Playing"),
                action: ActionClause(actions: ["logPlayStart"]))),
            .transition(TransitionStmt(
                source: .state(StateRef("Playing")),
                event:  .event(EventDecl(name: "stop")),
                destination: StateRef("Stopped"),
                action: ActionClause(actions: ["logStop"]))),
        ]
    )
}

/// Machine with guards on a transition (US-5.7).
func makeCheckoutFile() -> UrkelFile {
    UrkelFile(
        machineName: "Checkout",
        contextType: "CheckoutContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, name: "Cart")),
            .simple(SimpleStateDecl(kind: .state,  name: "Processing")),
            .simple(SimpleStateDecl(kind: .state,  name: "NoPaymentMethod")),
            .simple(SimpleStateDecl(kind: .final,  name: "Complete")),
        ],
        transitions: [
            // Guarded: checkout -> Processing [hasPaymentMethod]
            .transition(TransitionStmt(
                source: .state(StateRef("Cart")),
                event:  .event(EventDecl(name: "checkout")),
                guard: .named("hasPaymentMethod"),
                destination: StateRef("Processing"))),
            // Guarded: checkout -> NoPaymentMethod [else]
            .transition(TransitionStmt(
                source: .state(StateRef("Cart")),
                event:  .event(EventDecl(name: "checkout")),
                guard: .else,
                destination: StateRef("NoPaymentMethod"))),
            // Unguarded
            .transition(TransitionStmt(
                source: .state(StateRef("Processing")),
                event:  .event(EventDecl(name: "confirm")),
                destination: StateRef("Complete"))),
        ]
    )
}

/// Machine with an internal in-place transition (US-5.8).
func makeVideoPlayerFile() -> UrkelFile {
    UrkelFile(
        machineName: "VideoPlayer",
        contextType: "VideoContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
            .simple(SimpleStateDecl(kind: .state,  name: "Playing")),
            .simple(SimpleStateDecl(kind: .final,  name: "Stopped")),
        ],
        transitions: [
            .transition(TransitionStmt(
                source: .state(StateRef("Idle")),
                event:  .event(EventDecl(name: "play")),
                destination: StateRef("Playing"))),
            // Internal in-place: seek -* Playing with action
            .transition(TransitionStmt(
                source: .state(StateRef("Playing")),
                arrow: .`internal`,
                event:  .event(EventDecl(name: "seek",
                                         params: [Parameter(label: "position", typeExpr: "Double")])),
                destination: StateRef("Playing"),
                action: ActionClause(actions: ["emitSeekUI"]))),
            .transition(TransitionStmt(
                source: .state(StateRef("Playing")),
                event:  .event(EventDecl(name: "stop")),
                destination: StateRef("Stopped"))),
        ]
    )
}

/// Machine with an eventless always transition (US-5.9).
func makeBootFile() -> UrkelFile {
    UrkelFile(
        machineName: "App",
        contextType: "AppContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, name: "Boot")),
            .simple(SimpleStateDecl(kind: .state,  name: "Dashboard")),
            .simple(SimpleStateDecl(kind: .final,  name: "Exited")),
        ],
        transitions: [
            // Eventless: Boot -> always -> Dashboard
            .transition(TransitionStmt(
                source: .state(StateRef("Boot")),
                event:  .always,
                destination: StateRef("Dashboard"))),
            .transition(TransitionStmt(
                source: .state(StateRef("Dashboard")),
                event:  .event(EventDecl(name: "exit")),
                destination: StateRef("Exited"))),
        ]
    )
}

// MARK: - US-5.4: Final State Output

@Suite("US-5.4 — Final State Output")
struct FinalStateOutputTests {

    @Test("state data enum is emitted when final states have params")
    func stateDataEnumEmitted() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeLoginFile())
        #expect(files.stateMachine.contains("_LoginStateData"))
        #expect(files.stateMachine.contains("case success(user: User)"))
        #expect(files.stateMachine.contains("case failure(error: AuthError)"))
    }

    @Test("state data enum has a 'none' case")
    func stateDataEnumHasNone() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeLoginFile())
        #expect(files.stateMachine.contains("case none"))
    }

    @Test("machine struct stores _stateData")
    func machineStructHasStateData() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeLoginFile())
        #expect(files.stateMachine.contains("fileprivate let _stateData: _LoginStateData"))
    }

    @Test("borrowing var properties on terminal phase with params")
    func borrowingVarOnFinalPhase() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeLoginFile())
        #expect(files.stateMachine.contains("public borrowing var user: User"))
        #expect(files.stateMachine.contains("public borrowing var error: AuthError"))
    }

    @Test("transition to final state captures state data")
    func transitionCapturesStateData() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeLoginFile())
        #expect(files.stateMachine.contains("_stateData: .success(user: user)"))
        #expect(files.stateMachine.contains("_stateData: .failure(error: error)"))
    }

    @Test("transition to non-param final state uses .none")
    func transitionToNoParamFinalUsesNone() throws {
        // Stopped has no params in the FolderWatch fixture
        let file = makeFolderWatchFile()
        let emitter = SwiftSyntaxEmitter()
        let sdStates = emitter.statesWithData(in: file)
        #expect(sdStates.isEmpty, "FolderWatch has no param states")
        // No state data should appear in output
        let files = try emitter.emit(file: file)
        #expect(!files.stateMachine.contains("_stateData"))
    }

    @Test("stateMachine file with final-output parses without errors")
    func generatedFileParsesClean() throws {
        try SwiftSyntaxEmitter().validate(source:
            try SwiftSyntaxEmitter().emit(file: makeLoginFile()).stateMachine)
    }
}

// MARK: - US-5.5: State-Carried Data (non-final)

@Suite("US-5.5 — State-Carried Data")
struct StateCarriedDataTests {

    @Test("state data enum covers non-final param states")
    func stateDataCoverstIntermediateState() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeDataFetchFile())
        #expect(files.stateMachine.contains("_DataFetchStateData"))
        #expect(files.stateMachine.contains("case loaded(data: Data, source: URL)"))
    }

    @Test("borrowing var properties on non-final phase with params")
    func borrowingVarOnNonFinalPhase() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeDataFetchFile())
        #expect(files.stateMachine.contains("public borrowing var data: Data"))
        #expect(files.stateMachine.contains("public borrowing var source: URL"))
    }

    @Test("transition to loaded state captures both params")
    func transitionCapturesMultipleParams() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeDataFetchFile())
        #expect(files.stateMachine.contains("_stateData: .loaded(data: data, source: source)"))
    }

    @Test("transition leaving param state uses .none for param-less destination")
    func leavingParamStateUsesNone() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeDataFetchFile())
        // accept() -> Done (no params) should use .none
        #expect(files.stateMachine.contains("_stateData: .none"))
    }

    @Test("all emitted files parse without errors (DataFetch)")
    func dataFetchFilesParseClean() throws {
        let emitter = SwiftSyntaxEmitter()
        let files   = try emitter.emit(file: makeDataFetchFile())
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

// MARK: - US-5.6: Actions & Entry/Exit Hooks

@Suite("US-5.6 — Actions and Entry/Exit Hooks")
struct ActionsEntryExitTests {

    @Test("action closures declared in machine struct")
    func actionClosuresInStruct() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makePlayerFile())
        #expect(files.stateMachine.contains("_logPlayStart"))
        #expect(files.stateMachine.contains("_logStop"))
        #expect(files.stateMachine.contains("_startAnalytics"))
        #expect(files.stateMachine.contains("_stopAnalytics"))
    }

    @Test("action closure type is async Void not throws")
    func actionClosureTypeIsVoid() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makePlayerFile())
        #expect(files.stateMachine.contains("async -> Void"))
    }

    @Test("transition action is called in transition method body")
    func transitionActionCalledInBody() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makePlayerFile())
        #expect(files.stateMachine.contains("await _logPlayStart("))
    }

    @Test("entry hook called after transition in method body")
    func entryHookCalledAfterTransition() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makePlayerFile())
        #expect(files.stateMachine.contains("await _startAnalytics("))
    }

    @Test("exit hook called before transition in method body")
    func exitHookCalledBeforeTransition() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makePlayerFile())
        #expect(files.stateMachine.contains("await _stopAnalytics("))
    }

    @Test("action typealias and field appear in client runtime")
    func actionInClientRuntime() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makePlayerFile())
        #expect(files.client.contains("LogPlayStartAction"))
        #expect(files.client.contains("logPlayStartAction"))
    }

    @Test("all emitted files parse without errors (Player)")
    func playerFilesParseClean() throws {
        let emitter = SwiftSyntaxEmitter()
        let files   = try emitter.emit(file: makePlayerFile())
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

// MARK: - US-5.7: Guards

@Suite("US-5.7 — Guards")
struct GuardsTests {

    @Test("guard predicate closure declared in machine struct")
    func guardClosureInStruct() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeCheckoutFile())
        #expect(files.stateMachine.contains("_hasPaymentMethod"))
        #expect(files.stateMachine.contains("async -> Bool"))
    }

    @Test("guarded transition method returns combined state enum")
    func guardedTransitionReturnsStateEnum() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeCheckoutFile())
        // The checkout() method should return CheckoutState
        #expect(files.stateMachine.contains("-> CheckoutState"))
    }

    @Test("guarded method has if/else branches")
    func guardedMethodHasBranches() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeCheckoutFile())
        #expect(files.stateMachine.contains("await _hasPaymentMethod("))
        #expect(files.stateMachine.contains("} else {"))
    }

    @Test("guarded transition uses destination-qualified closure names")
    func guardedUsesDestinationQualifiedNames() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeCheckoutFile())
        // _checkoutToProcessing and _checkoutToNoPaymentMethod
        #expect(files.stateMachine.contains("_checkoutToProcessing"))
        #expect(files.stateMachine.contains("_checkoutToNoPaymentMethod"))
    }

    @Test("guard typealias and field appear in client runtime")
    func guardInClientRuntime() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeCheckoutFile())
        #expect(files.client.contains("HasPaymentMethodGuard"))
        #expect(files.client.contains("hasPaymentMethodGuard"))
    }

    @Test("all emitted files parse without errors (Checkout)")
    func checkoutFilesParseClean() throws {
        let emitter = SwiftSyntaxEmitter()
        let files   = try emitter.emit(file: makeCheckoutFile())
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

// MARK: - US-5.8: Internal In-Place Transitions

@Suite("US-5.8 — Internal In-Place Transitions")
struct InternalTransitionTests {

    @Test("in-place transition generates borrowing func")
    func inPlaceGeneratesBorrowingFunc() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerFile())
        #expect(files.stateMachine.contains("public borrowing func seek("))
    }

    @Test("in-place method returns Void (async, not consuming)")
    func inPlaceMethodIsVoidNotConsuming() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerFile())
        #expect(files.stateMachine.contains("borrowing func seek(position: Double) async"))
        // Must NOT have 'consuming func seek'
        #expect(!files.stateMachine.contains("consuming func seek("))
    }

    @Test("in-place action is called in method body")
    func inPlaceActionCalled() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerFile())
        #expect(files.stateMachine.contains("await _emitSeekUI("))
    }

    @Test("all emitted files parse without errors (VideoPlayer)")
    func videoPlayerFilesParseClean() throws {
        let emitter = SwiftSyntaxEmitter()
        let files   = try emitter.emit(file: makeVideoPlayerFile())
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

// MARK: - US-5.9: Eventless / Always Transitions

@Suite("US-5.9 — Eventless Transitions")
struct EventlessTransitionTests {

    @Test("always transition generates autoTransition method")
    func alwaysGeneratesAutoTransition() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeBootFile())
        #expect(files.stateMachine.contains("func autoTransition()"))
    }

    @Test("unconditional always returns specific phase type")
    func unconditionalAlwaysReturnsSpecificPhase() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeBootFile())
        #expect(files.stateMachine.contains("-> AppMachine<AppPhase.Dashboard>"))
    }

    @Test("all emitted files parse without errors (App/Boot)")
    func bootFilesParseClean() throws {
        let emitter = SwiftSyntaxEmitter()
        let files   = try emitter.emit(file: makeBootFile())
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

import Testing
import Foundation
@testable import Urkel

// MARK: - US-5.11 Fixture

func makeScaleFile() -> UrkelFile {
    UrkelFile(
        machineName: "Scale",
        contextType: "ScaleContext",
        imports: [ImportDecl(name: "BLE")],
        states: [
            .simple(SimpleStateDecl(kind: .`init`, params: [], name: "Off")),
            .simple(SimpleStateDecl(kind: .state, params: [], name: "WakingUp")),
            .simple(SimpleStateDecl(kind: .state, params: [Parameter(label: "weight", typeExpr: "Double")], name: "Weighing")),
            .simple(SimpleStateDecl(kind: .final, params: [], name: "PowerDown")),
        ],
        transitions: [
            .transition(TransitionStmt(source: .state(StateRef("Off")), event: .event(EventDecl(name: "footTap")), destination: StateRef("WakingUp"))),
            .transition(TransitionStmt(source: .state(StateRef("WakingUp")), event: .event(EventDecl(name: "hardwareReady")), destination: StateRef("Weighing"), fork: ForkClause(machine: "BLE"))),
            .transition(TransitionStmt(source: .state(StateRef("Weighing")), event: .event(EventDecl(name: "weightLocked", params: [Parameter(label: "weight", typeExpr: "Double")])), destination: StateRef("PowerDown"))),
            .reactive(ReactiveStmt(source: ReactiveSource(target: .machine("BLE"), state: .named("Connected")), ownState: "Weighing", arrow: .internal, destination: nil, action: ActionClause(actions: ["updateBLEStatus"]))),
            .reactive(ReactiveStmt(source: ReactiveSource(target: .machine("BLE"), state: .named("Error")), ownState: nil, arrow: .standard, destination: StateRef("PowerDown"), action: nil)),
        ]
    )
}

// MARK: - US-5.12 Fixture

func makeVideoPlayerCompoundFile() -> UrkelFile {
    let playingCompound = CompoundStateDecl(
        name: "Playing",
        history: .shallow,
        children: [
            SimpleStateDecl(kind: .`init`, params: [], name: "Buffering"),
            SimpleStateDecl(kind: .state, params: [], name: "Streaming"),
            SimpleStateDecl(kind: .state, params: [], name: "Paused"),
        ],
        innerTransitions: [
            TransitionStmt(source: .state(StateRef("Playing.Buffering")), event: .event(EventDecl(name: "bufferReady")), destination: StateRef("Playing.Streaming")),
            TransitionStmt(source: .state(StateRef("Playing.Streaming")), event: .event(EventDecl(name: "pause")), destination: StateRef("Playing.Paused")),
            TransitionStmt(source: .state(StateRef("Playing.Paused")), event: .event(EventDecl(name: "resume")), destination: StateRef("Playing.Streaming")),
        ]
    )
    return UrkelFile(
        machineName: "VideoPlayer",
        contextType: "PlayerContext",
        states: [
            .simple(SimpleStateDecl(kind: .`init`, params: [Parameter(label: "url", typeExpr: "URL")], name: "Idle")),
            .compound(playingCompound),
            .simple(SimpleStateDecl(kind: .final, params: [], name: "Stopped")),
        ],
        transitions: [
            .transition(TransitionStmt(source: .state(StateRef("Idle")), event: .event(EventDecl(name: "load", params: [Parameter(label: "url", typeExpr: "URL")])), destination: StateRef("Playing"))),
            .transition(TransitionStmt(source: .state(StateRef("Playing")), event: .event(EventDecl(name: "stop")), destination: StateRef("Stopped"))),
            .transition(TransitionStmt(source: .state(StateRef("Playing")), event: .event(EventDecl(name: "error")), destination: StateRef("Idle"))),
        ]
    )
}

// MARK: - US-5.11 Tests

@Suite("US-5.11 — Machine Composition")
struct MachineCompositionTests {
    @Test("machine struct has _xState sub-machine state property")
    func machineHasSubMachineStateProperty() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        #expect(files.stateMachine.contains("_bLEState"))
    }
    @Test("machine struct has _makeX factory property")
    func machineHasMakeFactoryProperty() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        #expect(files.stateMachine.contains("_makeBLE"))
    }
    @Test("fork transition calls _makeX() and passes fresh state")
    func forkTransitionSpawnsSubMachine() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        #expect(files.stateMachine.contains("let bLE = _makeBLE()"))
        #expect(files.stateMachine.contains("_bLEState: bLE"))
    }
    @Test("non-fork transitions carry _xState forward")
    func nonForkTransitionsCarryState() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        #expect(files.stateMachine.contains("_bLEState: _bLEState"))
    }
    @Test("borrowing reactive method on combined state enum")
    func borrowingReactiveMethodEmitted() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        #expect(files.stateMachine.contains("onBLEConnected"))
        #expect(files.stateMachine.contains("borrowing func onBLEConnected"))
    }
    @Test("consuming reactive method on combined state enum")
    func consumingReactiveMethodEmitted() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        #expect(files.stateMachine.contains("onBLEError"))
        #expect(files.stateMachine.contains("consuming func onBLEError"))
    }
    @Test("client makeObserver accepts sub-machine factory param")
    func clientMakeObserverHasFactoryParam() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        #expect(files.client.contains("() -> BLEState"))
    }
    @Test("all Scale files parse without errors")
    func scaleFilesParse() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeScaleFile())
        let emitter = SwiftSyntaxEmitter()
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

// MARK: - US-5.12 Tests

@Suite("US-5.12 — Compound States")
struct CompoundStateTests {
    @Test("phase namespace has nested Playing enum with children")
    func nestedPhaseNamespace() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        #expect(files.stateMachine.contains("public enum Playing {"))
        #expect(files.stateMachine.contains("public enum Buffering {}"))
        #expect(files.stateMachine.contains("public enum Streaming {}"))
        #expect(files.stateMachine.contains("public enum Paused {}"))
    }
    @Test("inner state enum VideoPlayerPlayingState is generated")
    func innerStateEnumGenerated() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        #expect(files.stateMachine.contains("VideoPlayerPlayingState"))
        #expect(files.stateMachine.contains("enum VideoPlayerPlayingState: ~Copyable"))
    }
    @Test("machine struct has compound inner state property")
    func machineHasInnerStateProperty() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        #expect(files.stateMachine.contains("_playingInnerState"))
        #expect(files.stateMachine.contains("VideoPlayerPlayingState?"))
    }
    @Test("bufferReady extension for Playing.Buffering -> Playing.Streaming")
    func bufferReadyExtension() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        #expect(files.stateMachine.contains("Phase == VideoPlayerPhase.Playing.Buffering"))
        #expect(files.stateMachine.contains("func bufferReady"))
    }
    @Test("pause extension for Playing.Streaming -> Playing.Paused")
    func pauseExtension() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        #expect(files.stateMachine.contains("Phase == VideoPlayerPhase.Playing.Streaming"))
        #expect(files.stateMachine.contains("func pause"))
    }
    @Test("stop generates extension for each child of Playing")
    func stopExtendsAllChildren() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        let sm = files.stateMachine
        let bufferingExt = sm.contains("Phase == VideoPlayerPhase.Playing.Buffering")
        let streamingExt = sm.contains("Phase == VideoPlayerPhase.Playing.Streaming")
        let pausedExt = sm.contains("Phase == VideoPlayerPhase.Playing.Paused")
        #expect(bufferingExt && streamingExt && pausedExt)
        #expect(sm.contains("func stop"))
    }
    @Test("combined state enum uses VideoPlayerPlayingState for playing case")
    func combinedStateUsesInnerEnum() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        #expect(files.stateMachine.contains("case playing(VideoPlayerPlayingState)"))
    }
    @Test("all VideoPlayer files parse without errors")
    func videoPlayerFilesParse() throws {
        let files = try SwiftSyntaxEmitter().emit(file: makeVideoPlayerCompoundFile())
        let emitter = SwiftSyntaxEmitter()
        try emitter.validate(source: files.stateMachine)
        try emitter.validate(source: files.client)
        try emitter.validate(source: files.dependency)
    }
}

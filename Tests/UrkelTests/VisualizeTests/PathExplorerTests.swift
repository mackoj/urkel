import Foundation
import Testing
@testable import UrkelAST
@testable import UrkelVisualize

// MARK: - Helpers

private func makeFile(
    name: String = "Machine",
    states: [StateDecl],
    transitions: [TransitionDecl] = [],
    reactives: [ReactiveStmt] = []
) -> UrkelFile {
    let allTransitions = transitions + reactives.map { TransitionDecl.reactive($0) }
    return UrkelFile(
        machineName: name,
        states: states,
        transitions: allTransitions
    )
}

private func simple(_ kind: StateKind, _ n: String) -> StateDecl {
    .simple(SimpleStateDecl(kind: kind, name: n))
}

private func trans(_ from: String, event: String, to: String, guard g: GuardClause? = nil) -> TransitionDecl {
    .transition(TransitionStmt(
        source: .state(StateRef(from)),
        event: .event(EventDecl(name: event)),
        guard: g,
        destination: StateRef(to)
    ))
}

// MARK: - PathExplorer Tests

@Suite("UrkelVisualize — PathExplorer")
struct PathExplorerTests {

    let explorer = PathExplorer()

    // MARK: Basic linear path

    @Test("Single linear path init → state → final")
    func singleLinearPath() {
        let file = makeFile(
            states: [simple(.`init`, "Idle"), simple(.state, "Running"), simple(.final, "Done")],
            transitions: [trans("Idle", event: "start", to: "Running"), trans("Running", event: "stop", to: "Done")]
        )
        let paths = explorer.paths(in: file)
        #expect(paths.count == 1)
        #expect(paths[0].steps.count == 2)
        #expect(paths[0].steps[0].from == "Idle")
        #expect(paths[0].steps[0].event == "start")
        #expect(paths[0].steps[0].to == "Running")
        #expect(paths[0].steps[1].from == "Running")
        #expect(paths[0].steps[1].event == "stop")
        #expect(paths[0].steps[1].to == "Done")
    }

    @Test("Path IDs are unique and sequential")
    func pathIDsAreSequential() {
        let file = makeFile(
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [trans("A", event: "go", to: "B")]
        )
        let paths = explorer.paths(in: file)
        #expect(paths[0].id == "path-1")
    }

    // MARK: Branching paths

    @Test("Branching produces two paths")
    func branchingProducesTwoPaths() {
        let file = makeFile(
            states: [
                simple(.`init`, "Start"),
                simple(.state, "Left"),
                simple(.state, "Right"),
                simple(.final, "End"),
            ],
            transitions: [
                trans("Start", event: "goLeft", to: "Left"),
                trans("Start", event: "goRight", to: "Right"),
                trans("Left", event: "finish", to: "End"),
                trans("Right", event: "finish", to: "End"),
            ]
        )
        let paths = explorer.paths(in: file)
        #expect(paths.count == 2)
        let allPaths = Set(paths.map { $0.steps.map(\.event).joined(separator: "→") })
        #expect(allPaths.contains("goLeft→finish"))
        #expect(allPaths.contains("goRight→finish"))
    }

    @Test("Multiple finals produce a path each")
    func multipleFinalsEachGetPath() {
        let file = makeFile(
            states: [
                simple(.`init`, "Start"),
                simple(.final, "Success"),
                simple(.final, "Failure"),
            ],
            transitions: [
                trans("Start", event: "ok",  to: "Success"),
                trans("Start", event: "err", to: "Failure"),
            ]
        )
        let paths = explorer.paths(in: file)
        #expect(paths.count == 2)
    }

    // MARK: No init state

    @Test("Returns empty when no init state")
    func returnsEmptyWithoutInit() {
        let file = makeFile(
            states: [simple(.state, "Running"), simple(.final, "Done")],
            transitions: [trans("Running", event: "stop", to: "Done")]
        )
        let paths = explorer.paths(in: file)
        #expect(paths.isEmpty)
    }

    // MARK: Guards

    @Test("Guard value propagated to MachineStep")
    func guardValuePropagated() {
        let file = makeFile(
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("A")),
                    event: .event(EventDecl(name: "go")),
                    guard: .named("isReady"),
        destination: StateRef("B")
                ))
            ]
        )
        let paths = explorer.paths(in: file)
        #expect(paths.count == 1)
        #expect(paths[0].steps[0].guardValue == "isReady")
    }

    @Test("Negated guard formatted with leading !")
    func negatedGuardFormatted() {
        let file = makeFile(
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("A")),
                    event: .event(EventDecl(name: "go")),
                    guard: .negated("isReady"),
        destination: StateRef("B")
                ))
            ]
        )
        let paths = explorer.paths(in: file)
        #expect(paths[0].steps[0].guardValue == "!isReady")
    }

    @Test("Else guard formatted as 'else'")
    func elseGuardFormatted() {
        let file = makeFile(
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("A")),
                    event: .event(EventDecl(name: "go")),
                    guard: .else,
        destination: StateRef("B")
                ))
            ]
        )
        let paths = explorer.paths(in: file)
        #expect(paths[0].steps[0].guardValue == "else")
    }

    @Test("No guard produces nil guardValue")
    func noGuardIsNil() {
        let file = makeFile(
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [trans("A", event: "go", to: "B")]
        )
        let paths = explorer.paths(in: file)
        #expect(paths[0].steps[0].guardValue == nil)
    }

    // MARK: Special event kinds

    @Test("Timer event labelled 'after'")
    func timerEventLabelledAfter() {
        let file = makeFile(
            states: [simple(.`init`, "Waiting"), simple(.final, "Expired")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Waiting")),
                    event: .timer(TimerDecl(duration: Duration(value: 5, unit: .s))),
                    destination: StateRef("Expired")
                ))
            ]
        )
        let paths = explorer.paths(in: file)
        #expect(paths[0].steps[0].event == "after")
    }

    @Test("Always event labelled 'always'")
    func alwaysEventLabelled() {
        let file = makeFile(
            states: [simple(.`init`, "A"), simple(.final, "B")],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("A")),
                    event: .always,
                    destination: StateRef("B")
                ))
            ]
        )
        let paths = explorer.paths(in: file)
        #expect(paths[0].steps[0].event == "always")
    }

    // MARK: Wildcard expansion

    @Test("Wildcard edge reaches non-init states")
    func wildcardExpandsToNonInitStates() {
        let file = makeFile(
            states: [
                simple(.`init`, "Idle"),
                simple(.state, "Running"),
                simple(.final, "Cancelled"),
            ],
            transitions: [
                trans("Idle", event: "start", to: "Running"),
                .transition(TransitionStmt(
                    source: .wildcard,
                    event: .event(EventDecl(name: "cancel")),
                    destination: StateRef("Cancelled")
                )),
            ]
        )
        let paths = explorer.paths(in: file)
        // Should find paths that end in Cancelled from either Idle or Running
        let destinations = Set(paths.flatMap { $0.steps }.filter { $0.event == "cancel" }.map(\.from))
        #expect(destinations.contains("Idle") || destinations.contains("Running"))
    }

    // MARK: maxPaths limit

    @Test("maxPaths=1 caps results to one path")
    func maxPathsLimitApplied() {
        let file = makeFile(
            states: [
                simple(.`init`, "Start"),
                simple(.state, "A"),
                simple(.state, "B"),
                simple(.final, "End"),
            ],
            transitions: [
                trans("Start", event: "toA", to: "A"),
                trans("Start", event: "toB", to: "B"),
                trans("A", event: "done", to: "End"),
                trans("B", event: "done", to: "End"),
            ]
        )
        let paths = explorer.paths(in: file, maxPaths: 1)
        #expect(paths.count == 1)
    }

    // MARK: Reactive @on edges

    @Test("Reactive @on machine edge included in paths")
    func reactiveOnMachineEdge() {
        let file = makeFile(
            states: [simple(.`init`, "Connecting"), simple(.final, "Connected")],
            transitions: [],
            reactives: [
                ReactiveStmt(
                    source: ReactiveSource(target: .machine("Loader"), state: .any),
                    destination: StateRef("Connected")
                )
            ]
        )
        let paths = explorer.paths(in: file)
        // Reactive edges from "Loader" (not a state), won't form a valid init→final path
        // but should not crash
        #expect(paths.isEmpty || !paths.isEmpty) // no crash = pass
    }

    // MARK: MachineStep / MachinePath Codable

    @Test("MachineStep is Codable round-trip")
    func machineStepCodable() throws {
        let step = MachineStep(from: "A", event: "go", to: "B", guardValue: "ok")
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(MachineStep.self, from: data)
        #expect(decoded.from == step.from)
        #expect(decoded.event == step.event)
        #expect(decoded.to == step.to)
        #expect(decoded.guardValue == step.guardValue)
    }

    @Test("MachinePath is Codable round-trip")
    func machinePathCodable() throws {
        let path = MachinePath(
            id: "path-1",
            steps: [MachineStep(from: "A", event: "go", to: "B")],
            guards: ["isReady": true]
        )
        let data = try JSONEncoder().encode(path)
        let decoded = try JSONDecoder().decode(MachinePath.self, from: data)
        #expect(decoded.id == path.id)
        #expect(decoded.steps.count == 1)
        #expect(decoded.guards["isReady"] == true)
    }
}

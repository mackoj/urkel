import Testing
@testable import UrkelAST
@testable import UrkelVisualize

// MARK: - Helpers

private func simple(_ kind: StateKind, _ n: String) -> StateDecl {
    .simple(SimpleStateDecl(kind: kind, name: n))
}

private func trans(
    _ from: String,
    event: String,
    to: String,
    guard g: GuardClause? = nil
) -> TransitionDecl {
    .transition(TransitionStmt(
        source: .state(StateRef(from)),
        event: .event(EventDecl(name: event)),
        guard: g,
        destination: StateRef(to)
    ))
}

// MARK: - MermaidRenderer Tests

@Suite("UrkelVisualize — MermaidRenderer")
struct MermaidRendererTests {

    let renderer = MermaidRenderer()

    // MARK: Header

    @Test("Output begins with stateDiagram-v2")
    func outputBeginsWithHeader() {
        let file = UrkelFile(machineName: "M", states: [simple(.`init`, "A"), simple(.final, "B")],
                             transitions: [trans("A", event: "go", to: "B")])
        let output = renderer.render(file)
        #expect(output.hasPrefix("stateDiagram-v2"))
    }

    // MARK: Init / Final state markers

    @Test("Init state produces [*] --> Name line")
    func initStateProducesEntryArrow() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "Idle"), simple(.final, "Done")],
                             transitions: [trans("Idle", event: "done", to: "Done")])
        let output = renderer.render(file)
        #expect(output.contains("[*] --> Idle"))
    }

    @Test("Final state produces Name --> [*] line")
    func finalStateProducesExitArrow() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "Idle"), simple(.final, "Done")],
                             transitions: [trans("Idle", event: "done", to: "Done")])
        let output = renderer.render(file)
        #expect(output.contains("Done --> [*]"))
    }

    @Test("Regular state produces no extra [*] lines")
    func regularStateProducesNoMarker() {
        let file = UrkelFile(machineName: "M",
                             states: [
                                 simple(.`init`, "Idle"),
                                 simple(.state, "Running"),
                                 simple(.final, "Done"),
                             ],
                             transitions: [
                                 trans("Idle", event: "start", to: "Running"),
                                 trans("Running", event: "stop", to: "Done"),
                             ])
        let output = renderer.render(file)
        let lines = output.split(separator: "\n")
        let starLines = lines.filter { $0.contains("[*]") }
        // Exactly 2: one for init entry, one for final exit
        #expect(starLines.count == 2)
    }

    // MARK: Transitions

    @Test("Named event transition rendered correctly")
    func namedEventTransition() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "Idle"), simple(.final, "Done")],
                             transitions: [trans("Idle", event: "start", to: "Done")])
        let output = renderer.render(file)
        #expect(output.contains("Idle --> Done : start"))
    }

    @Test("Timer transition rendered with after(value+unit) label")
    func timerTransitionLabel() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "Waiting"), simple(.final, "Expired")],
                             transitions: [
                                 .transition(TransitionStmt(
                                     source: .state(StateRef("Waiting")),
                                     event: .timer(TimerDecl(duration: Duration(value: 30, unit: .s))),
                                     destination: StateRef("Expired")
                                 ))
                             ])
        let output = renderer.render(file)
        #expect(output.contains("Waiting --> Expired : after(30s)"))
    }

    @Test("Timer with ms unit renders correctly")
    func timerMsUnit() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "W"), simple(.final, "E")],
                             transitions: [
                                 .transition(TransitionStmt(
                                     source: .state(StateRef("W")),
                                     event: .timer(TimerDecl(duration: Duration(value: 500, unit: .ms))),
                                     destination: StateRef("E")
                                 ))
                             ])
        let output = renderer.render(file)
        #expect(output.contains("W --> E : after(500ms)"))
    }

    @Test("Always transition rendered with 'always' label")
    func alwaysTransitionLabel() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "A"), simple(.final, "B")],
                             transitions: [
                                 .transition(TransitionStmt(
                                     source: .state(StateRef("A")),
                                     event: .always,
                                     destination: StateRef("B")
                                 ))
                             ])
        let output = renderer.render(file)
        #expect(output.contains("A --> B : always"))
    }

    // MARK: Guards

    @Test("Guarded transition appends [guard] to label")
    func guardedTransitionLabel() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "A"), simple(.final, "B")],
                             transitions: [
                                 .transition(TransitionStmt(
                                     source: .state(StateRef("A")),
                                     event: .event(EventDecl(name: "go")),
                                     guard: .named("isReady"),
        destination: StateRef("B")
                                 ))
                             ])
        let output = renderer.render(file)
        #expect(output.contains("A --> B : go [guard]"))
    }

    @Test("Unguarded transition has no [guard] suffix")
    func unguardedTransitionNoSuffix() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "A"), simple(.final, "B")],
                             transitions: [trans("A", event: "go", to: "B")])
        let output = renderer.render(file)
        #expect(!output.contains("[guard]"))
    }

    // MARK: Transition with nil destination

    @Test("Transition with nil destination uses [*] as target")
    func nilDestinationUsesStar() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "A"), simple(.final, "B")],
                             transitions: [
                                 .transition(TransitionStmt(
                                     source: .state(StateRef("A")),
                                     event: .event(EventDecl(name: "abort")),
                                     destination: nil
                                 ))
                             ])
        let output = renderer.render(file)
        #expect(output.contains("A --> [*] : abort"))
    }

    // MARK: Multiple transitions

    @Test("All transitions appear in output")
    func allTransitionsPresent() {
        let file = UrkelFile(machineName: "M",
                             states: [
                                 simple(.`init`, "Idle"),
                                 simple(.state, "Running"),
                                 simple(.final, "Done"),
                             ],
                             transitions: [
                                 trans("Idle", event: "start", to: "Running"),
                                 trans("Running", event: "stop", to: "Done"),
                             ])
        let output = renderer.render(file)
        #expect(output.contains("Idle --> Running : start"))
        #expect(output.contains("Running --> Done : stop"))
    }

    // MARK: Empty machine

    @Test("Machine with no transitions only contains header and state markers")
    func emptyTransitions() {
        let file = UrkelFile(machineName: "M",
                             states: [simple(.`init`, "A"), simple(.final, "B")],
                             transitions: [])
        let output = renderer.render(file)
        #expect(output.contains("stateDiagram-v2"))
        #expect(output.contains("[*] --> A"))
        #expect(output.contains("B --> [*]"))
        #expect(!output.contains("-->  :")) // no blank-event lines
    }
}

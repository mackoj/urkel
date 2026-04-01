import Testing
@testable import Urkel

@Suite("US 3.1 + 3.2 - Validator")
struct UrkelValidatorTests {

    @Test("No diagnostics for valid machine")
    func validMachineProducesNoDiagnostics() {
        let file = UrkelFile(
            machineName: "Test",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .state, name: "Running")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(source: .state(StateRef("Idle")), event: .event(EventDecl(name: "start")), destination: StateRef("Running"))),
                .transition(TransitionStmt(source: .state(StateRef("Running")), event: .event(EventDecl(name: "finish")), destination: StateRef("Done"))),
            ]
        )
        let diags = UrkelValidator.validate(file).filter { $0.severity == .error }
        #expect(diags.isEmpty)
    }

    @Test("Missing init state produces error")
    func missingInitState() {
        let file = UrkelFile(
            machineName: "Test",
            states: [.simple(SimpleStateDecl(kind: .state, name: "Running"))]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == .missingInitState && $0.severity == .error })
    }

    @Test("Multiple init states produces error")
    func multipleInitStates() {
        let file = UrkelFile(
            machineName: "Test",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .`init`, name: "Boot")),
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == .multipleInitStates })
    }

    @Test("Duplicate state name produces error")
    func duplicateStateName() {
        let file = UrkelFile(
            machineName: "Test",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .state, name: "Idle")),
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == .duplicateStateName && $0.message.contains("Idle") })
    }

    @Test("Unresolved transition destination produces error")
    func unresolvedDestination() {
        let file = UrkelFile(
            machineName: "Test",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Idle")),
                    event: .event(EventDecl(name: "go")),
                    destination: StateRef("Typo")
                )),
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == .undefinedStateReference && $0.message.contains("Typo") })
    }

    @Test("Unreachable state produces warning")
    func unreachableState() {
        let file = UrkelFile(
            machineName: "Test",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .state, name: "NeverReached")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(source: .state(StateRef("Idle")), event: .event(EventDecl(name: "finish")), destination: StateRef("Done"))),
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == .unreachableState && $0.message.contains("NeverReached") })
    }

    @Test("validateThrowing throws on error diagnostics")
    func validateThrowingRaisesErrors() {
        let file = UrkelFile(
            machineName: "Test",
            states: [.simple(SimpleStateDecl(kind: .state, name: "Running"))]
        )
        #expect(throws: UrkelValidationError.self) {
            try UrkelValidator.validateThrowing(file)
        }
    }

    @Test("validateThrowing succeeds for valid machine")
    func validateThrowingSucceeds() throws {
        let file = UrkelFile(
            machineName: "Test",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(source: .state(StateRef("Idle")), event: .event(EventDecl(name: "finish")), destination: StateRef("Done"))),
            ]
        )
        try UrkelValidator.validateThrowing(file)
    }

    @Test("BYOT types are accepted without errors")
    func byotTypeAccepted() throws {
        let file = UrkelFile(
            machineName: "Test",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Idle")),
                    event: .event(EventDecl(name: "load", params: [Parameter(label: "data", typeExpr: "[String: Any]?")])),
                    destination: StateRef("Done")
                )),
            ]
        )
        try UrkelValidator.validateThrowing(file)
    }
}

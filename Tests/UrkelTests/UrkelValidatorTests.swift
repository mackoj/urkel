import Testing
@testable import Urkel

@Suite("US 3.1 + 3.2 - Validator")
struct UrkelValidatorTests {
    @Test("Throws missingInitialState when none is present")
    func missingInitialState() {
        let ast = MachineAST(
            imports: [],
            machineName: "Broken",
            contextType: nil,
            factory: nil,
            states: [.init(name: "Running", kind: .normal)],
            transitions: []
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected missing initial state")
        } catch let error as UrkelValidationError {
            #expect(error == .missingInitialState)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws multipleInitialStates when more than one init exists")
    func multipleInitialStates() {
        let ast = MachineAST(
            imports: [],
            machineName: "Broken",
            contextType: nil,
            factory: nil,
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Boot", kind: .initial)
            ],
            transitions: []
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected multiple initial states")
        } catch let error as UrkelValidationError {
            #expect(error == .multipleInitialStates)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws unresolvedStateReference for misspelled state")
    func unresolvedStateReference() {
        let ast = MachineAST(
            imports: [],
            machineName: "Broken",
            contextType: nil,
            factory: nil,
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal)
            ],
            transitions: [
                .init(from: "Idle", event: "start", parameters: [], to: "Runing")
            ]
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected unresolved reference")
        } catch let error as UrkelValidationError {
            #expect(error == .unresolvedStateReference(stateName: "Runing"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("BYOT types are ignored during semantic validation")
    func byotTypeIgnored() throws {
        let ast = MachineAST(
            imports: [],
            machineName: "Byot",
            contextType: nil,
            factory: nil,
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal)
            ],
            transitions: [
                .init(
                    from: "Idle",
                    event: "deviceFound",
                    parameters: [.init(name: "param", type: "!@#NotRealSwift")],
                    to: "Running"
                )
            ]
        )

        try UrkelValidator.validate(ast)
    }
}

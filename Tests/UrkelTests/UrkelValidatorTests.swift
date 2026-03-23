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

    @Test("Throws unresolvedComposedMachine for undeclared fork target")
    func unresolvedComposedMachine() {
        let ast = MachineAST(
            imports: [],
            machineName: "Scale",
            contextType: nil,
            factory: nil,
            composedMachines: ["BLE"],
            states: [
                .init(name: "WakingUp", kind: .initial),
                .init(name: "Tare", kind: .normal),
            ],
            transitions: [
                .init(from: "WakingUp", event: "hardwareReady", parameters: [], to: "Tare", spawnedMachine: "WiFi")
            ]
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected unresolved composed machine")
        } catch let error as UrkelValidationError {
            #expect(error == .unresolvedComposedMachine(machineName: "WiFi"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws duplicateState for repeated state names")
    func duplicateState() {
        let ast = MachineAST(
            imports: [],
            machineName: "Broken",
            contextType: nil,
            factory: nil,
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Idle", kind: .normal)
            ],
            transitions: []
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected duplicate state")
        } catch let error as UrkelValidationError {
            #expect(error == .duplicateState(stateName: "Idle"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws duplicateTransition for repeated transition signatures")
    func duplicateTransition() {
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
                .init(from: "Idle", event: "start", parameters: [], to: "Running"),
                .init(from: "Idle", event: "start", parameters: [], to: "Running")
            ]
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected duplicate transition")
        } catch let error as UrkelValidationError {
            #expect(error == .duplicateTransition(from: "Idle", event: "start", to: "Running"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws unreachableState when a state cannot be reached from init")
    func unreachableState() {
        let ast = MachineAST(
            imports: [],
            machineName: "Broken",
            contextType: nil,
            factory: nil,
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal),
                .init(name: "NeverReached", kind: .normal)
            ],
            transitions: [
                .init(from: "Idle", event: "start", parameters: [], to: "Running")
            ]
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected unreachable state")
        } catch let error as UrkelValidationError {
            #expect(error == .unreachableState(stateName: "NeverReached"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Strict terminal semantics reject outgoing transitions from final states")
    func strictTerminalSemantics() {
        let ast = MachineAST(
            imports: [],
            machineName: "Broken",
            contextType: nil,
            factory: nil,
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Done", kind: .terminal)
            ],
            transitions: [
                .init(from: "Idle", event: "finish", parameters: [], to: "Done"),
                .init(from: "Done", event: "restart", parameters: [], to: "Idle")
            ]
        )

        do {
            try UrkelValidator.validate(ast, options: .init(strictTerminalStateSemantics: true))
            Issue.record("Expected strict terminal semantics failure")
        } catch let error as UrkelValidationError {
            #expect(error == .terminalStateHasOutgoingTransitions(stateName: "Done"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Throws missingContinuationReturnType when continuation has no declared type")
    func missingContinuationReturnType() throws {
        let ast = MachineAST(
            imports: [],
            machineName: "FolderWatch",
            contextType: nil,
            factory: nil,
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal),
                .init(name: "Stopped", kind: .terminal)
            ],
            transitions: [
                .init(from: "Idle", event: "start", parameters: [], to: "Running"),
                .init(from: "Running", event: "events", parameters: [], to: nil),
                .init(from: "Running", event: "stop", parameters: [], to: "Stopped")
            ]
        )

        do {
            try UrkelValidator.validate(ast)
            Issue.record("Expected missingContinuationReturnType error")
        } catch let error as UrkelValidationError {
            #expect(error == .missingContinuationReturnType(event: "events"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

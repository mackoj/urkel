import Testing
@testable import UrkelAST
@testable import UrkelValidation

@Suite("UrkelValidation — Diagnostic model")
struct DiagnosticTests {

    // MARK: SourceRange

    @Test("SourceRange stores start and end positions")
    func sourceRangeStoresPositions() {
        let start = SourceRange.Position(line: 1, column: 4)
        let end   = SourceRange.Position(line: 1, column: 10)
        let range = SourceRange(start: start, end: end)
        #expect(range.start.line == 1)
        #expect(range.start.column == 4)
        #expect(range.end.line == 1)
        #expect(range.end.column == 10)
    }

    @Test("SourceRange.Position equality")
    func positionEquality() {
        let p1 = SourceRange.Position(line: 3, column: 7)
        let p2 = SourceRange.Position(line: 3, column: 7)
        let p3 = SourceRange.Position(line: 3, column: 8)
        #expect(p1 == p2)
        #expect(p1 != p3)
    }

    @Test("SourceRange equality")
    func sourceRangeEquality() {
        let r1 = SourceRange(start: .init(line: 0, column: 0), end: .init(line: 0, column: 5))
        let r2 = SourceRange(start: .init(line: 0, column: 0), end: .init(line: 0, column: 5))
        let r3 = SourceRange(start: .init(line: 1, column: 0), end: .init(line: 1, column: 5))
        #expect(r1 == r2)
        #expect(r1 != r3)
    }

    // MARK: DiagnosticCode

    @Test("DiagnosticCode has all expected raw values")
    func diagnosticCodeRawValues() {
        #expect(DiagnosticCode.missingInitState.rawValue     == "missingInitState")
        #expect(DiagnosticCode.multipleInitStates.rawValue   == "multipleInitStates")
        #expect(DiagnosticCode.missingFinalState.rawValue    == "missingFinalState")
        #expect(DiagnosticCode.undefinedStateReference.rawValue == "undefinedStateReference")
        #expect(DiagnosticCode.undefinedEntryExitState.rawValue == "undefinedEntryExitState")
        #expect(DiagnosticCode.duplicateStateName.rawValue   == "duplicateStateName")
        #expect(DiagnosticCode.unreachableState.rawValue     == "unreachableState")
        #expect(DiagnosticCode.deadState.rawValue            == "deadState")
        #expect(DiagnosticCode.elseGuardNotLast.rawValue     == "elseGuardNotLast")
        #expect(DiagnosticCode.duplicateGuardBranch.rawValue == "duplicateGuardBranch")
        #expect(DiagnosticCode.undeclaredImportInFork.rawValue == "undeclaredImportInFork")
        #expect(DiagnosticCode.determinismViolation.rawValue == "determinismViolation")
    }

    // MARK: Diagnostic

    @Test("Diagnostic stores all fields")
    func diagnosticStoresFields() {
        let range = SourceRange(start: .init(line: 2, column: 0), end: .init(line: 2, column: 8))
        let d = Diagnostic(severity: .error, code: .duplicateStateName, message: "Dup", range: range)
        #expect(d.severity == .error)
        #expect(d.code == .duplicateStateName)
        #expect(d.message == "Dup")
        #expect(d.range == range)
    }

    @Test("Diagnostic without range has nil range")
    func diagnosticNilRange() {
        let d = Diagnostic(severity: .warning, code: .unreachableState, message: "Warn")
        #expect(d.range == nil)
    }

    @Test("Diagnostic severity equality")
    func severityEquality() {
        #expect(Diagnostic.Severity.error == .error)
        #expect(Diagnostic.Severity.warning == .warning)
        #expect(Diagnostic.Severity.error != .warning)
    }

    @Test("Diagnostic equality")
    func diagnosticEquality() {
        let d1 = Diagnostic(severity: .error, code: .missingInitState, message: "Missing")
        let d2 = Diagnostic(severity: .error, code: .missingInitState, message: "Missing")
        let d3 = Diagnostic(severity: .warning, code: .missingInitState, message: "Missing")
        #expect(d1 == d2)
        #expect(d1 != d3)
    }
}

// MARK: - Validator edge cases

@Suite("UrkelValidation — Validator edge cases")
struct ValidatorEdgeCaseTests {

    // MARK: Entry/exit hooks

    @Test("Entry hook referencing unknown state produces undefinedEntryExitState error")
    func entryHookUnknownStateError() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            entryExitHooks: [
                EntryExitDecl(hook: .entry, state: StateRef("Ghost"), actions: ["doSomething"])
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Idle")),
                    event: .event(EventDecl(name: "go")),
                    destination: StateRef("Done")
                ))
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == DiagnosticCode.undefinedEntryExitState && $0.message.contains("Ghost") })
    }

    @Test("Entry hook referencing known state produces no error")
    func entryHookKnownStateNoError() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            entryExitHooks: [
                EntryExitDecl(hook: .entry, state: StateRef("Idle"), actions: ["log"])
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Idle")),
                    event: .event(EventDecl(name: "go")),
                    destination: StateRef("Done")
                ))
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(!diags.contains { $0.code == DiagnosticCode.undefinedEntryExitState })
    }

    // MARK: Fork / @import

    @Test("Fork referencing undeclared @import produces undeclaredImportInFork error")
    func forkUndeclaredImport() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Idle")),
                    event: .event(EventDecl(name: "go")),
                    destination: StateRef("Done"),
                    fork: ForkClause(machine: "SubMachine", bindings: [])
                ))
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == DiagnosticCode.undeclaredImportInFork && $0.message.contains("SubMachine") })
    }

    @Test("Fork with declared @import produces no import error")
    func forkDeclaredImportNoError() {
        let file = UrkelFile(
            machineName: "M",
            imports: [ImportDecl(name: "SubMachine")],
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Idle")),
                    event: .event(EventDecl(name: "go")),
                    destination: StateRef("Done"),
                    fork: ForkClause(machine: "SubMachine", bindings: [])
                ))
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(!diags.contains { $0.code == DiagnosticCode.undeclaredImportInFork })
    }

    // MARK: Duplicate names in compound children

    @Test("Duplicate name between outer and compound child is caught")
    func duplicateNameOuterAndChild() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .compound(CompoundStateDecl(
                    name: "Active",
                    children: [
                        SimpleStateDecl(kind: .`init`, name: "Idle"), // conflict
                        SimpleStateDecl(kind: .final, name: "Done"),
                    ]
                )),
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == .duplicateStateName && $0.message.contains("Idle") })
    }

    // MARK: Transition source reference checks

    @Test("Transition from unknown source state produces error")
    func transitionFromUnknownSource() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Ghost")),
                    event: .event(EventDecl(name: "go")),
                    destination: StateRef("Done")
                ))
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(diags.contains { $0.code == .undefinedStateReference && $0.message.contains("Ghost") })
    }

    @Test("Wildcard source does not trigger undefined state error")
    func wildcardSourceNoError() {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .wildcard,
                    event: .event(EventDecl(name: "cancel")),
                    destination: StateRef("Done")
                ))
            ]
        )
        let diags = UrkelValidator.validate(file)
        #expect(!diags.contains { $0.code == .undefinedStateReference })
    }

    // MARK: UrkelValidationError

    @Test("UrkelValidationError localizedDescription matches message")
    func validationErrorDescription() {
        let err = UrkelValidationError("bad machine")
        #expect(err.errorDescription == "bad machine")
        #expect(err.message == "bad machine")
    }
}

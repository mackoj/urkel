import Testing
@testable import Urkel

@Suite("US 2.1 - AST")
struct MachineASTTests {
    @Test("UrkelFile supports full model and equality")
    func urkelFileEquality() {
        let f1 = UrkelFile(
            machineName: "FolderWatch",
            contextType: "FolderContext",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .state, name: "Running")),
                .simple(SimpleStateDecl(kind: .final, name: "Stopped")),
            ]
        )
        let f2 = UrkelFile(
            machineName: "FolderWatch",
            contextType: "FolderContext",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .state, name: "Running")),
                .simple(SimpleStateDecl(kind: .final, name: "Stopped")),
            ]
        )
        #expect(f1 == f2)
        #expect(f1.initState?.name == "Idle")
        #expect(f1.finalStates.count == 1)
        #expect(f1.contextType == "FolderContext")
    }
}

import Testing
@testable import Urkel

@Suite("US 2.1 - AST")
struct MachineASTTests {
    @Test("MachineAST supports full model and equality")
    func astEquality() {
        let lhs = makeFolderWatchAST()
        let rhs = makeFolderWatchAST()
        #expect(lhs == rhs)
        #expect(lhs.factory?.parameters.count == 2)
        #expect(lhs.states.first?.kind == .initial)
        #expect(lhs.range == nil)
    }
}

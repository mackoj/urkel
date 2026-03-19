import Testing
@testable import Urkel

@Suite("US 6.1 - LSP")
struct LSPTests {
    @Test("Semantic diagnostics for unresolved state")
    func unresolvedStateDiagnostic() async {
        let source = """
        @states
          init Idle
        @transitions
          Idle -> start -> Missing
        """

        let diagnostics = await UrkelLanguageServer().diagnostics(for: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].message.contains("Unresolved state reference: Missing"))
    }

    @Test("Syntax diagnostics for malformed transition")
    func syntaxDiagnostic() async {
        let source = """
        @states
          init Idle
        @transitions
          Idle ->
        """

        let diagnostics = await UrkelLanguageServer().diagnostics(for: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].message.contains("Transition must follow"))
    }
}

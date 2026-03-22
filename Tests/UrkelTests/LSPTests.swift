import LanguageServerProtocol
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

        let diagnostics = await UrkelLanguageServer().diagnostics(in: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].message.contains("Unresolved state reference: Missing"))
    }

    @Test("Semantic diagnostics include duplicate state validation")
    func duplicateStateDiagnostic() async {
        let source = """
        machine Example
        @states
          init Idle
          state Idle
        @transitions
          Idle -> start -> Idle
        """

        let diagnostics = await UrkelLanguageServer().diagnostics(in: source)
        #expect(diagnostics.contains(where: { $0.message.contains("Duplicate state declaration: Idle") }))
    }

    @Test("Semantic diagnostics include unreachable state validation")
    func unreachableStateDiagnostic() async {
        let source = """
        machine Example
        @states
          init Idle
          state NeverReached
        @transitions
          Idle -> start -> Idle
        """

        let diagnostics = await UrkelLanguageServer().diagnostics(in: source)
        #expect(diagnostics.contains(where: { $0.message.contains("Unreachable state: NeverReached") }))
    }

    @Test("Syntax diagnostics for malformed transition")
    func syntaxDiagnostic() async {
        let source = """
        @states
          init Idle
        @transitions
          Idle ->
        """

        let diagnostics = await UrkelLanguageServer().diagnostics(in: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].message.contains("Transition must follow"))
    }

    @Test("Document formatting canonicalizes the source")
    func formattingCanonicalizesSource() async {
        let server = UrkelLanguageServer()
        let uri: DocumentUri = "file:///Formatting.urkel"
        let source = """
          machine Example
          @states
            state Running
            init Idle
          @transitions
            Idle -> start -> Running
        """
        let expected = """
        machine Example
        @states
          state Running
          init Idle
        @transitions
          Idle -> start -> Running
        """

        _ = await server.didOpen(uri: uri, text: source)
        let edits = await server.formattingEdits(for: uri)

        #expect(edits.count == 1)
        #expect(edits[0].newText == expected)
    }

    @Test("Completion suggests states and keywords")
    func completionSuggestions() async {
        let server = UrkelLanguageServer()
        let uri: DocumentUri = "file:///Completion.urkel"
        let source = """
        machine Example
        @states
          init Idle
          state Running
        @transitions
          Idle ->
        """

        _ = await server.didOpen(uri: uri, text: source)
        let response = await server.completion(for: uri, position: .init(line: 5, character: 9))

        let labels = response?.items.map(\.label) ?? []
        #expect(labels.contains("Running"))
        #expect(labels.contains("start"))
        #expect(labels.contains("init"))
        #expect(labels.contains("Idle"))
    }

    @Test("Hover describes machine pieces")
    func hoverDescriptions() async {
        let server = UrkelLanguageServer()
        let uri: DocumentUri = "file:///Hover.urkel"
        let source = """
        machine Example
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """

        _ = await server.didOpen(uri: uri, text: source)
        let hover = await server.hover(for: uri, position: .init(line: 5, character: 9))

        #expect(hover != nil)
        #expect(hover?.range != nil)
    }

    @Test("Semantic tokens include syntax")
    func semanticTokensIncludeSyntax() async {
        let server = UrkelLanguageServer()
        let uri: DocumentUri = "file:///Tokens.urkel"
        let source = """
        machine Example
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """

        _ = await server.didOpen(uri: uri, text: source)
        let tokens = await server.semanticTokens(for: uri)

        #expect(tokens != nil)
        #expect(tokens?.data.isEmpty == false)
        #expect(tokens?.data.count.isMultiple(of: 5) == true)
    }

    @Test("Semantic tokens still return for partial transition lines")
    func semanticTokensBestEffortForPartialSource() async {
        let server = UrkelLanguageServer()
        let uri: DocumentUri = "file:///PartialTokens.urkel"
        let source = """
        machine Example
        @states
          init Idle
          state Running
        @transitions
          Idle -> start(
        """

        _ = await server.didOpen(uri: uri, text: source)
        let tokens = await server.semanticTokens(for: uri)
        #expect(tokens != nil)
        #expect(tokens?.data.isEmpty == false)
    }

    @Test("Completions still suggest values when transition line is incomplete")
    func completionBestEffortForPartialSource() async {
        let server = UrkelLanguageServer()
        let uri: DocumentUri = "file:///PartialCompletion.urkel"
        let source = """
        machine Example
        @states
          init Idle
          state Running
        @transitions
          Idle -> star
        """

        _ = await server.didOpen(uri: uri, text: source)
        let response = await server.completion(for: uri, position: .init(line: 5, character: 14))
        let labels = response?.items.map(\.label) ?? []
        #expect(labels.contains("start"))
        #expect(labels.contains("Idle"))
        #expect(labels.contains("Running"))
    }

    @Test("Code actions offer quick fixes")
    func codeActionsOfferFixes() async {
        let server = UrkelLanguageServer()
        let uri: DocumentUri = "file:///Actions.urkel"
        let source = """
        machine Example
        @states
          state Idle
          state Running
        @transitions
          Idle -> start -> Missing
        """

        _ = await server.didOpen(uri: uri, text: source)
        let diagnostics = await server.diagnostics(for: uri) ?? []
        let actions = await server.codeActions(
            for: uri,
            .zero,
            diagnostics: diagnostics
        )

        let titles = actions?.compactMap { action -> String? in
            if case let .optionB(codeAction) = action {
                return codeAction.title
            }
            return nil
        } ?? []

        #expect(titles.contains { $0.contains("Mark Idle as initial") })
        #expect(titles.contains { $0.contains("Replace Missing") })
    }
}

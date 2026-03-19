import Foundation
import LanguageServerProtocol

public struct UrkelDiagnostic: Equatable, Sendable {
    public let line: Int
    public let column: Int
    public let message: String
    public let severity: Int

    public init(line: Int, column: Int, message: String, severity: Int = 1) {
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
    }
}

public actor UrkelLanguageServer {
    private struct DocumentState: Sendable {
        var text: String
        var version: Int?
    }

    private enum TokenKind: Int, CaseIterable, Sendable {
        case keyword = 0
        case type = 1
        case namespace = 2
        case event = 3
        case parameter = 4
        case function = 5
        case comment = 6
    }

    private var documents: [DocumentUri: DocumentState] = [:]

    public init() {}

    public func didOpen(uri: DocumentUri, text: String, version: Int? = nil) -> PublishDiagnosticsParams {
        documents[uri] = DocumentState(text: text, version: version)
        return publishDiagnostics(uri: uri, text: text, version: version)
    }

    public func didChange(uri: DocumentUri, text: String, version: Int? = nil) -> PublishDiagnosticsParams {
        documents[uri] = DocumentState(text: text, version: version)
        return publishDiagnostics(uri: uri, text: text, version: version)
    }

    public func didClose(uri: DocumentUri) -> PublishDiagnosticsParams {
        documents[uri] = nil
        return PublishDiagnosticsParams(uri: uri, diagnostics: [])
    }

    public func diagnostics(in source: String) -> [UrkelDiagnostic] {
        return lspDiagnostics(for: source).map {
            UrkelDiagnostic(
                line: $0.range.start.line + 1,
                column: $0.range.start.character + 1,
                message: $0.message,
                severity: $0.severity?.rawValue ?? DiagnosticSeverity.error.rawValue
            )
        }
    }

    public func diagnostics(for uri: DocumentUri) -> [Diagnostic]? {
        guard let source = documents[uri]?.text else { return nil }
        return lspDiagnostics(for: source)
    }

    public func source(for uri: DocumentUri) -> String? {
        documents[uri]?.text
    }

    public func formattingEdits(in source: String) -> [TextEdit] {
        do {
            let ast = try parseValidated(source)
            let formatted = UrkelParser().print(ast: ast)
            return [TextEdit(range: fullDocumentRange(for: source), newText: formatted)]
        } catch {
            return []
        }
    }

    public func formattingEdits(for uri: DocumentUri) -> [TextEdit] {
        guard let source = documents[uri]?.text else { return [] }
        return formattingEdits(in: source)
    }

    public func completion(for uri: DocumentUri, position: Position) -> CompletionResponse {
        guard let source = documents[uri]?.text else { return nil }
        let items = completionItems(for: source, position: position)
        return items.isEmpty ? nil : .optionB(CompletionList(isIncomplete: false, items: items))
    }

    public func hover(for uri: DocumentUri, position: Position) -> HoverResponse {
        guard let source = documents[uri]?.text else { return nil }
        return hover(in: source, position: position)
    }

    public func codeActions(
        for uri: DocumentUri,
        _ range: LSPRange,
        diagnostics: [Diagnostic]
    ) -> CodeActionResponse {
        guard let source = documents[uri]?.text else { return nil }
        guard let ast = try? UrkelParser().parse(source: source) else { return nil }

        var actions: [TwoTypeOption<Command, CodeAction>] = []

        for diagnostic in diagnostics {
            if diagnostic.message.contains("Machine is missing exactly one initial state.") {
                if let action = makeInitialStateFix(uri: uri, source: source, ast: ast) {
                    actions.append(.optionB(action))
                }
                continue
            }

            if diagnostic.message.hasPrefix("Unresolved state reference:") {
                if let action = makeRenameFix(uri: uri, ast: ast, diagnostic: diagnostic) {
                    actions.append(.optionB(action))
                }
            }
        }

        return actions.isEmpty ? nil : actions
    }

    public func semanticTokens(for uri: DocumentUri) -> SemanticTokensResponse {
        guard let source = documents[uri]?.text else { return nil }
        guard let ast = try? UrkelParser().parse(source: source) else { return nil }

        let tokens = semanticTokens(for: source, ast: ast)
        return SemanticTokens(tokens: tokens)
    }

    public func initializationResponse() -> InitializationResponse {
        var capabilities = ServerCapabilities()
        capabilities.textDocumentSync = .optionA(
            TextDocumentSyncOptions(openClose: true, change: .full, willSave: nil, willSaveWaitUntil: nil, save: nil)
        )
        capabilities.completionProvider = CompletionOptions(
            workDoneProgress: false,
            triggerCharacters: ["@", ":", ">"],
            allCommitCharacters: nil,
            resolveProvider: false,
            completionItem: .init(labelDetailsSupport: true)
        )
        capabilities.hoverProvider = .optionA(true)
        capabilities.codeActionProvider = .optionA(true)
        capabilities.documentFormattingProvider = .optionA(true)
        capabilities.documentRangeFormattingProvider = .optionA(true)
        capabilities.semanticTokensProvider = .optionA(
            SemanticTokensOptions(
                workDoneProgress: nil,
                legend: Self.semanticTokensLegend,
                range: nil,
                full: .optionA(true)
            )
        )

        return InitializationResponse(
            capabilities: capabilities,
            serverInfo: ServerInfo(name: "Urkel", version: nil)
        )
    }
}

public extension UrkelLanguageServer {
    static let semanticTokensLegend = SemanticTokensLegend(
        tokenTypes: [
            SemanticTokenTypes.keyword.rawValue,
            SemanticTokenTypes.type.rawValue,
            SemanticTokenTypes.namespace.rawValue,
            SemanticTokenTypes.event.rawValue,
            SemanticTokenTypes.parameter.rawValue,
            SemanticTokenTypes.function.rawValue,
            SemanticTokenTypes.comment.rawValue
        ],
        tokenModifiers: []
    )
}

private extension UrkelLanguageServer {
    func publishDiagnostics(uri: DocumentUri, text: String, version: Int?) -> PublishDiagnosticsParams {
        PublishDiagnosticsParams(uri: uri, version: version, diagnostics: lspDiagnostics(for: text))
    }

    func lspDiagnostics(for source: String) -> [Diagnostic] {
        do {
            let ast = try UrkelParser().parse(source: source)
            try UrkelValidator.validate(ast)
            return []
        } catch let parse as UrkelParseError {
            return [
                Diagnostic(
                    range: lspRange(line: parse.line, column: parse.column, length: 1),
                    severity: .error,
                    source: "urkel",
                    message: parse.message
                )
            ]
        } catch let validation as UrkelValidationError {
            return validationDiagnostics(validation, source: source)
        } catch {
            return [
                Diagnostic(
                    range: .zero,
                    severity: .error,
                    source: "urkel",
                    message: String(describing: error)
                )
            ]
        }
    }

    func validationDiagnostics(_ validation: UrkelValidationError, source: String) -> [Diagnostic] {
        guard let ast = try? UrkelParser().parse(source: source) else {
            return [
                Diagnostic(
                    range: .zero,
                    severity: .error,
                    source: "urkel",
                    message: validation.localizedDescription
                )
            ]
        }

        switch validation {
        case .missingInitialState:
            guard let state = ast.states.first else {
                return [Diagnostic(range: .zero, severity: .error, source: "urkel", message: validation.localizedDescription)]
            }
            return [
                Diagnostic(
                    range: keywordRange(for: state, in: source) ?? range(for: state.range) ?? .zero,
                    severity: .error,
                    source: "urkel",
                    message: validation.localizedDescription
                )
            ] + unresolvedReferenceDiagnostics(ast: ast, source: source)
        case .multipleInitialStates:
            let initialStates = ast.states.filter { $0.kind == .initial }
            return initialStates.map {
                Diagnostic(
                    range: keywordRange(for: $0, in: source) ?? range(for: $0.range) ?? .zero,
                    severity: .error,
                    source: "urkel",
                    message: validation.localizedDescription
                )
            }
        case .unresolvedStateReference(let stateName):
            return unresolvedReferenceDiagnostics(stateName: stateName, ast: ast, source: source)
        }
    }

    func unresolvedReferenceDiagnostics(ast: MachineAST, source: String) -> [Diagnostic] {
        let knownStates = Set(ast.states.map(\.name))
        var diagnostics: [Diagnostic] = []

        for transition in ast.transitions {
            if !knownStates.contains(transition.from),
               let range = referenceRange(in: source, token: transition.from, line: transition.range?.start.line)
            {
                diagnostics.append(
                    Diagnostic(
                        range: range,
                        severity: .error,
                        source: "urkel",
                        message: "Unresolved state reference: \(transition.from)"
                    )
                )
            }

            if !knownStates.contains(transition.to),
               let range = referenceRange(in: source, token: transition.to, line: transition.range?.start.line)
            {
                diagnostics.append(
                    Diagnostic(
                        range: range,
                        severity: .error,
                        source: "urkel",
                        message: "Unresolved state reference: \(transition.to)"
                    )
                )
            }
        }

        return diagnostics
    }

    func unresolvedReferenceDiagnostics(stateName: String, ast: MachineAST, source: String) -> [Diagnostic] {
        var matches: [Diagnostic] = []

        for transition in ast.transitions {
            if transition.from == stateName, let range = referenceRange(in: source, token: stateName, line: transition.range?.start.line) {
                matches.append(
                    Diagnostic(range: range, severity: .error, source: "urkel", message: "Unresolved state reference: \(stateName)")
                )
            }
            if transition.to == stateName, let range = referenceRange(in: source, token: stateName, line: transition.range?.start.line) {
                matches.append(
                    Diagnostic(range: range, severity: .error, source: "urkel", message: "Unresolved state reference: \(stateName)")
                )
            }
        }

        return matches.isEmpty
            ? [Diagnostic(range: .zero, severity: .error, source: "urkel", message: "Unresolved state reference: \(stateName)")]
            : matches
    }

    func parseValidated(_ source: String) throws -> MachineAST {
        let ast = try UrkelParser().parse(source: source)
        try UrkelValidator.validate(ast)
        return ast
    }

    func completionItems(for source: String, position: Position) -> [CompletionItem] {
        let lines = normalizedLines(source)
        guard position.line < lines.count else { return [] }
        let line = lines[position.line]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let prefix = String(line.prefix(min(position.character, line.count))).trimmingCharacters(in: .whitespaces)
        let ast = try? UrkelParser().parse(source: source)

        var items: [CompletionItem] = []

        if trimmed.isEmpty || line.trimmingCharacters(in: .whitespaces).hasPrefix("@") || prefix.hasPrefix("@") {
            items.append(contentsOf: [
                CompletionItem(label: "@imports", kind: .keyword, detail: "Declare imports"),
                CompletionItem(label: "machine", kind: .keyword, detail: "Declare a machine"),
                CompletionItem(label: "@factory", kind: .keyword, detail: "Declare a factory"),
                CompletionItem(label: "@states", kind: .keyword, detail: "Declare states"),
                CompletionItem(label: "@transitions", kind: .keyword, detail: "Declare transitions")
            ])
        }

        if isInsideStatesBlock(lines: lines, lineIndex: position.line) {
            items.append(contentsOf: [
                CompletionItem(label: "init", kind: .keyword, detail: "Initial state"),
                CompletionItem(label: "state", kind: .keyword, detail: "Regular state"),
                CompletionItem(label: "final", kind: .keyword, detail: "Terminal state")
            ])
        }

        if isInsideTransitionsBlock(lines: lines, lineIndex: position.line) {
            items.append(contentsOf: [
                CompletionItem(label: "init", kind: .keyword, detail: "Initial state"),
                CompletionItem(label: "state", kind: .keyword, detail: "Regular state"),
                CompletionItem(label: "final", kind: .keyword, detail: "Terminal state")
            ])

            for name in ast?.states.map(\.name) ?? declaredStateNames(in: lines) {
                items.append(
                    CompletionItem(
                        label: name,
                        kind: .struct,
                        detail: "State"
                    )
                )
            }

            for transition in ast?.transitions ?? [] {
                items.append(
                    CompletionItem(
                        label: transition.event,
                        kind: .event,
                        detail: "Transition event"
                    )
                )
            }

            items.append(
                CompletionItem(
                    label: "start",
                    kind: .event,
                    detail: "Example event"
                )
            )
        }

        return deduplicatedCompletionItems(items)
    }

    func hover(in source: String, position: Position) -> HoverResponse {
        guard let ast = try? UrkelParser().parse(source: source) else { return nil }
        let lines = normalizedLines(source)
        guard position.line < lines.count else { return nil }

        let line = lines[position.line]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let word = word(at: position.character, in: line)

        if let word, word == "machine", let machineName = machineName(at: line) {
            return Hover(
                contents: "Urkel machine `\(machineName)`.",
                range: wordRange(in: line, word: word).map { lspRange(lineText: line, line: position.line + 1, range: $0) }
            )
        }

        if let word, let state = ast.states.first(where: { $0.name == word }) {
            let kind: String
            switch state.kind {
            case .initial: kind = "initial"
            case .normal: kind = "state"
            case .terminal: kind = "terminal"
            }

            return Hover(
                contents: "Urkel \(kind) `\(state.name)`.",
                range: range(for: state.range)
            )
        }

        if let word, let transition = ast.transitions.first(where: { $0.event == word }) {
            let parameters = transition.parameters.isEmpty
                ? ""
                : " with parameters \(transition.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", "))"
            return Hover(
                contents: "Transition event `\(transition.event)` from `\(transition.from)` to `\(transition.to)`\(parameters).",
                range: range(for: transition.range)
            )
        }

        if trimmed.contains("->"),
           let transition = ast.transitions.first(where: {
               $0.range?.start.line == position.line + 1 || transitionLineMatches($0, trimmedLine: trimmed)
           })
        {
            let parameters = transition.parameters.isEmpty
                ? ""
                : " with parameters \(transition.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", "))"
            return Hover(
                contents: "Transition event `\(transition.event)` from `\(transition.from)` to `\(transition.to)`\(parameters).",
                range: range(for: transition.range)
            )
        }

        if word == "@states" {
            return Hover(contents: "Declares the machine states section.")
        }

        if word == "@transitions" {
            return Hover(contents: "Declares the machine transitions section.")
        }

        return nil
    }

    func semanticTokens(for source: String, ast: MachineAST) -> [SemanticToken] {
        let lines = normalizedLines(source)
        var tokens: [SemanticToken] = []

        func addToken(lineIndex: Int, rawLine: String, range: Range<String.Index>, kind: TokenKind) {
            let lower = rawLine.distance(from: rawLine.startIndex, to: range.lowerBound)
            let length = rawLine.distance(from: range.lowerBound, to: range.upperBound)
            tokens.append(
                SemanticToken(
                    line: UInt32(lineIndex),
                    char: UInt32(lower),
                    length: UInt32(length),
                    type: UInt32(kind.rawValue)
                )
            )
        }

        for (lineIndex, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                addToken(lineIndex: lineIndex, rawLine: rawLine, range: rawLine.startIndex..<rawLine.endIndex, kind: .comment)
                continue
            }

            if trimmed.hasPrefix("@imports") {
                if let range = wordRange(in: rawLine, word: "@imports") {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .keyword)
                }
                continue
            }

            if trimmed.hasPrefix("machine ") {
                if let keyword = wordRange(in: rawLine, word: "machine") {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: keyword, kind: .keyword)
                }
                if let name = machineName(at: rawLine), let range = wordRange(in: rawLine, word: name) {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .namespace)
                }
                if let context = machineContext(at: rawLine), let range = wordRange(in: rawLine, word: context) {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .type)
                }
                continue
            }

            if trimmed.hasPrefix("@factory ") {
                if let keyword = wordRange(in: rawLine, word: "@factory") {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: keyword, kind: .keyword)
                }
                if let factory = ast.factory, let range = wordRange(in: rawLine, word: factory.name) {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .function)
                }
                for parameter in ast.factory?.parameters ?? [] {
                    if let range = wordRange(in: rawLine, word: parameter.name) {
                        addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .parameter)
                    }
                    if let range = wordRange(in: rawLine, word: parameter.type) {
                        addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .type)
                    }
                }
                continue
            }

            if isStateLine(trimmed) {
                if let kindWord = firstWord(in: trimmed), let range = wordRange(in: rawLine, word: kindWord) {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .keyword)
                }
                if let state = ast.states.first(where: { stateLineMatches(state: $0, rawLine: trimmed) }),
                   let range = wordRange(in: rawLine, word: state.name)
                {
                    addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .type)
                }
                continue
            }

            if isTransitionLine(trimmed) {
                if let transition = ast.transitions.first(where: { transitionLineMatches($0, trimmedLine: trimmed) }) {
                    if let range = wordRange(in: rawLine, word: transition.from) {
                        addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .type)
                    }
                    if let range = wordRange(in: rawLine, word: transition.event) {
                        addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .event)
                    }
                    if let range = wordRange(in: rawLine, word: transition.to) {
                        addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .type)
                    }
                    for parameter in transition.parameters {
                        if let range = wordRange(in: rawLine, word: parameter.name) {
                            addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .parameter)
                        }
                        if let range = wordRange(in: rawLine, word: parameter.type) {
                            addToken(lineIndex: lineIndex, rawLine: rawLine, range: range, kind: .type)
                        }
                    }
                }
                continue
            }
        }

        return tokens.sorted { $0.line == $1.line ? $0.char < $1.char : $0.line < $1.line }
    }

    func makeInitialStateFix(uri: DocumentUri, source: String, ast: MachineAST) -> CodeAction? {
        guard let state = ast.states.first else { return nil }
        guard let range = keywordRange(for: state, in: source) else { return nil }
        let edit = WorkspaceEdit(
            changes: [uri: [TextEdit(range: range, newText: "init")]],
            documentChanges: nil
        )

        return CodeAction(
            title: "Mark \(state.name) as initial",
            kind: CodeActionKind.Quickfix,
            diagnostics: nil,
            isPreferred: true,
            disabled: nil,
            edit: edit,
            command: nil,
            data: nil
        )
    }

    func makeRenameFix(
        uri: DocumentUri,
        ast: MachineAST,
        diagnostic: Diagnostic
    ) -> CodeAction? {
        guard let stateName = diagnostic.message.split(separator: ":").last.map({ $0.trimmingCharacters(in: .whitespaces) }),
              let bestMatch = bestMatchingState(named: stateName, in: ast)
        else { return nil }

        let edit = WorkspaceEdit(
            changes: [uri: [TextEdit(range: diagnostic.range, newText: bestMatch)]],
            documentChanges: nil
        )

        return CodeAction(
            title: "Replace \(stateName) with \(bestMatch)",
            kind: CodeActionKind.Quickfix,
            diagnostics: [diagnostic],
            isPreferred: true,
            disabled: nil,
            edit: edit,
            command: nil,
            data: nil
        )
    }

    func bestMatchingState(named name: String, in ast: MachineAST) -> String? {
        let candidates = ast.states.map(\.name)
        guard let best = candidates.min(by: { levenshteinDistance($0, name) < levenshteinDistance($1, name) }) else {
            return nil
        }

        return best == name ? nil : best
    }

    func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }
        var table = Array(repeating: Array(repeating: 0, count: rhs.count + 1), count: lhs.count + 1)

        for i in 0...lhs.count { table[i][0] = i }
        for j in 0...rhs.count { table[0][j] = j }

        for i in 1...lhs.count {
            for j in 1...rhs.count {
                if lhs[i - 1] == rhs[j - 1] {
                    table[i][j] = table[i - 1][j - 1]
                } else {
                    table[i][j] = min(table[i - 1][j - 1], table[i - 1][j], table[i][j - 1]) + 1
                }
            }
        }

        return table[lhs.count][rhs.count]
    }

    func deduplicatedCompletionItems(_ items: [CompletionItem]) -> [CompletionItem] {
        var seen: Set<String> = []
        var result: [CompletionItem] = []

        for item in items {
            if seen.insert(item.label).inserted {
                result.append(item)
            }
        }

        return result
    }

    func isInsideStatesBlock(lines: [String], lineIndex: Int) -> Bool {
        section(for: lineIndex, in: lines) == .states
    }

    func isInsideTransitionsBlock(lines: [String], lineIndex: Int) -> Bool {
        section(for: lineIndex, in: lines) == .transitions
    }

    enum Section {
        case imports
        case machine
        case factory
        case states
        case transitions
    }

    func section(for lineIndex: Int, in lines: [String]) -> Section? {
        var current: Section?
        for (index, line) in lines.enumerated() where index <= lineIndex {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("@imports") { current = .imports }
            else if trimmed.hasPrefix("machine ") { current = .machine }
            else if trimmed.hasPrefix("@factory ") { current = .factory }
            else if trimmed == "@states" { current = .states }
            else if trimmed == "@transitions" { current = .transitions }
        }
        return current
    }

    func normalizedLines(_ source: String) -> [String] {
        source.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    func lineText(in source: String, line: Int) -> String? {
        let lines = normalizedLines(source)
        guard line > 0, line <= lines.count else { return nil }
        return lines[line - 1]
    }

    func lspRange(line: Int, column: Int, length: Int = 1) -> LSPRange {
        LSPRange(
            start: Position(line: max(line - 1, 0), character: max(column - 1, 0)),
            end: Position(line: max(line - 1, 0), character: max(column - 1, 0) + max(length, 0))
        )
    }

    func lspRange(lineText: String, line: Int, range: Range<String.Index>) -> LSPRange {
        let start = lineText.distance(from: lineText.startIndex, to: range.lowerBound)
        let end = lineText.distance(from: lineText.startIndex, to: range.upperBound)
        return LSPRange(
            start: Position(line: max(line - 1, 0), character: start),
            end: Position(line: max(line - 1, 0), character: end)
        )
    }

    func range(for sourceRange: MachineAST.SourceRange?) -> LSPRange? {
        guard let sourceRange else { return nil }
        return LSPRange(
            start: Position(line: sourceRange.start.line - 1, character: max(sourceRange.start.column - 1, 0)),
            end: Position(line: sourceRange.end.line - 1, character: max(sourceRange.end.column, 0))
        )
    }

    func fullDocumentRange(for source: String) -> LSPRange {
        let lines = normalizedLines(source)
        guard let last = lines.indices.last else { return .zero }
        return LSPRange(
            start: .zero,
            end: Position(line: last, character: lines[last].count)
        )
    }

    func machineName(at line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("machine ") else { return nil }
        let remainder = trimmed.dropFirst("machine ".count)
        let head = remainder.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        return head.isEmpty ? nil : String(head)
    }

    func machineContext(at line: String) -> String? {
        guard let start = line.firstIndex(of: "<"), let end = line.lastIndex(of: ">"), start < end else {
            return nil
        }
        let context = line[line.index(after: start)..<end].trimmingCharacters(in: .whitespaces)
        return context.isEmpty ? nil : context
    }

    func word(at character: Int, in line: String) -> String? {
        guard !line.isEmpty else { return nil }
        let index = max(0, min(character, line.count.saturatingSubtraction(1)))
        guard let range = wordRange(in: line, at: index) else { return nil }
        return String(line[range])
    }

    func wordRange(in line: String, at character: Int) -> Range<String.Index>? {
        guard character < line.count else { return nil }
        let index = line.index(line.startIndex, offsetBy: character)
        guard line[index].isLetter || line[index].isNumber || line[index] == "_" || line[index] == "@" else {
            return nil
        }

        var lower = index
        var upper = index
        while lower > line.startIndex {
            let prev = line.index(before: lower)
            guard line[prev].isLetter || line[prev].isNumber || line[prev] == "_" || line[prev] == "@" else { break }
            lower = prev
        }
        while upper < line.index(before: line.endIndex) {
            let next = line.index(after: upper)
            guard line[next].isLetter || line[next].isNumber || line[next] == "_" || line[next] == "@" else { break }
            upper = next
        }
        return lower..<line.index(after: upper)
    }

    func wordRange(in line: String, word: String) -> Range<String.Index>? {
        guard let range = line.range(of: word) else { return nil }
        return range
    }

    func firstWord(in line: String) -> String? {
        line.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    func declaredStateNames(in lines: [String]) -> [String] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let prefixes = ["init ", "state ", "final "]
            guard let prefix = prefixes.first(where: { trimmed.hasPrefix($0) }) else { return nil }
            let remainder = trimmed.dropFirst(prefix.count)
            return remainder.split(whereSeparator: \.isWhitespace).first.map(String.init)
        }
    }

    func isStateLine(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("init ") || trimmed.hasPrefix("state ") || trimmed.hasPrefix("final ")
    }

    func isTransitionLine(_ trimmed: String) -> Bool {
        trimmed.contains("->")
    }

    func stateLineMatches(state: MachineAST.StateNode, rawLine: String) -> Bool {
        rawLine.contains(state.name)
    }

    func transitionLineMatches(_ transition: MachineAST.TransitionNode, trimmedLine: String) -> Bool {
        trimmedLine.contains(transition.from) && trimmedLine.contains(transition.event) && trimmedLine.contains(transition.to)
    }

    func keywordRange(for state: MachineAST.StateNode, in source: String) -> LSPRange? {
        let lineNumber = state.range?.start.line ?? 1
        guard let line = lineText(in: source, line: lineNumber) else { return nil }
        if let word = firstWord(in: line), let range = wordRange(in: line, word: word) {
            return lspRange(lineText: line, line: lineNumber, range: range)
        }
        return nil
    }

    func referenceRange(in source: String, token: String, line: Int?) -> LSPRange? {
        guard let line, let text = lineText(in: source, line: line) else { return nil }
        guard let range = text.range(of: token) else { return nil }
        return lspRange(lineText: text, line: line, range: range)
    }
}

private extension Int {
    func saturatingSubtraction(_ value: Int) -> Int {
        Swift.max(self - value, 0)
    }
}

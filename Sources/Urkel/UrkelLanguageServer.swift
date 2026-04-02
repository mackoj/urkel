import Foundation
import UrkelAST
import UrkelParser
import UrkelValidation
import LanguageServerProtocol

// Use explicit qualification to distinguish our Diagnostic from LanguageServerProtocol.Diagnostic
internal typealias LSPDiagnostic = LanguageServerProtocol.Diagnostic

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
        var cachedFile: CachedParse?
        var cachedLSPDiagnostics: [LSPDiagnostic]?
        var cachedSemanticTokenData: [UInt32]?
    }

    private enum CachedParse: Sendable {
        case success(UrkelFile)
        case failure(Error)
    }

    private enum TokenKind: Int, CaseIterable, Sendable {
        case keyword   = 0
        case type      = 1
        case namespace = 2
        case event     = 3
        case parameter = 4
        case function  = 5
        case comment   = 6
    }

    private var documents: [DocumentUri: DocumentState] = [:]

    public init() {}

    // MARK: - Document lifecycle

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

    public func source(for uri: DocumentUri) -> String? {
        documents[uri]?.text
    }

    // MARK: - Diagnostics

    public func diagnostics(in source: String) -> [UrkelDiagnostic] {
        // Go directly through the validator to avoid type-conversion issues
        do {
            let file = try UrkelParser.parse(source)
            return UrkelValidator.validate(file).map { d in
                UrkelDiagnostic(
                    line: 1,
                    column: 1,
                    message: d.message,
                    severity: d.severity == .error ? 1 : 2
                )
            }
        } catch let pe as UrkelParseError {
            return [UrkelDiagnostic(
                line: pe.line,
                column: pe.column ?? 1,
                message: pe.message,
                severity: 1
            )]
        } catch {
            return [UrkelDiagnostic(line: 1, column: 1, message: error.localizedDescription, severity: 1)]
        }
    }

    public func diagnostics(for uri: DocumentUri) -> [LanguageServerProtocol.Diagnostic]? {
        guard let text = documents[uri]?.text else { return nil }
        if let cached = documents[uri]?.cachedLSPDiagnostics { return cached }
        let diags = lspDiagnostics(for: text)
        documents[uri]?.cachedLSPDiagnostics = diags
        return diags
    }

    // MARK: - Formatting

    public func formattingEdits(in source: String) -> [TextEdit] {
        let formatted = UrkelParser().format(source)
        return [TextEdit(range: fullDocumentRange(for: source), newText: formatted)]
    }

    public func formattingEdits(for uri: DocumentUri) -> [TextEdit] {
        guard let source = documents[uri]?.text else { return [] }
        return formattingEdits(in: source)
    }

    // MARK: - Completion

    public func completion(for uri: DocumentUri, position: Position) -> CompletionResponse {
        guard let source = documents[uri]?.text else { return nil }
        let items = completionItems(for: source, position: position)
        return items.isEmpty ? nil : .optionB(CompletionList(isIncomplete: false, items: items))
    }

    // MARK: - Hover

    public func hover(for uri: DocumentUri, position: Position) -> HoverResponse {
        guard let source = documents[uri]?.text else { return nil }
        return hoverInfo(in: source, position: position)
    }

    // MARK: - Semantic Tokens

    public func semanticTokens(for uri: DocumentUri) -> SemanticTokensResponse {
        guard let source = documents[uri]?.text else { return nil }
        if let cached = documents[uri]?.cachedSemanticTokenData {
            return SemanticTokens(resultId: nil, data: cached)
        }
        let tokens = buildSemanticTokens(for: source)
        guard !tokens.isEmpty else { return nil }
        let encoded = Self.encodeSemanticTokens(tokens: tokens)
        documents[uri]?.cachedSemanticTokenData = encoded
        return SemanticTokens(resultId: nil, data: encoded)
    }

    // MARK: - Code Actions

    public func codeActions(
        for uri: DocumentUri,
        _ range: LSPRange,
        diagnostics: [LanguageServerProtocol.Diagnostic]
    ) -> CodeActionResponse {
        guard let source = documents[uri]?.text else { return nil }
        var actions: [TwoTypeOption<Command, CodeAction>] = []

        // Quick fix for missing init state
        if diagnostics.contains(where: { $0.message.contains("missing exactly one initial state") }) {
            let file = try? UrkelParser.parse(source)
            let firstStateName = file?.simpleStates.first(where: { $0.kind != .`init` })?.name
            if let name = firstStateName {
                let edit = TextEdit(
                    range: findStateKindRange(in: source, stateName: name) ?? .zero,
                    newText: "init \(name)"
                )
                let action = CodeAction(
                    title: "Mark \(name) as initial",
                    kind: CodeActionKind.Quickfix,
                    edit: WorkspaceEdit(changes: [uri: [edit]], documentChanges: nil)
                )
                actions.append(.optionB(action))
            }
        }

        // Quick fix for unresolved state references (typo fixes)
        for diag in diagnostics where diag.message.hasPrefix("Unresolved state reference:") {
            let badName = String(diag.message.dropFirst("Unresolved state reference:".count)).trimmingCharacters(in: .whitespaces)
            let file = try? UrkelParser.parse(source)
            let stateNames = file?.simpleStates.map(\.name) ?? []
            // Always offer the closest match (or first state) as replacement
            let replacement = stateNames
                .map { ($0, levenshtein(badName, $0)) }
                .min(by: { $0.1 < $1.1 })?
                .0 ?? stateNames.first
            if let closest = replacement {
                let edit = TextEdit(
                    range: findWordRange(in: source, word: badName) ?? .zero,
                    newText: closest
                )
                let action = CodeAction(
                    title: "Replace \(badName) with \(closest)",
                    kind: CodeActionKind.Quickfix,
                    edit: WorkspaceEdit(changes: [uri: [edit]], documentChanges: nil)
                )
                actions.append(.optionB(action))
            }
        }

        return actions.isEmpty ? nil : actions
    }

    // MARK: - Initialization

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

// MARK: - Semantic Tokens Legend

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

    static func encodeSemanticTokens(tokens: [SemanticToken]) -> [UInt32] {
        var result: [UInt32] = []
        var prevLine: UInt32 = 0
        var prevChar: UInt32 = 0
        for token in tokens.sorted(by: { $0.line < $1.line || ($0.line == $1.line && $0.char < $1.char) }) {
            let deltaLine  = token.line - prevLine
            let deltaStart = deltaLine == 0 ? token.char - prevChar : token.char
            result += [deltaLine, deltaStart, token.length, token.type, 0]
            prevLine = token.line
            prevChar = token.char
        }
        return result
    }
}

// MARK: - Private helpers

private extension UrkelLanguageServer {

    // MARK: Publish

    func publishDiagnostics(uri: DocumentUri, text: String, version: Int?) -> PublishDiagnosticsParams {
        let diags = lspDiagnostics(for: text)
        documents[uri]?.cachedLSPDiagnostics = diags
        return PublishDiagnosticsParams(uri: uri, version: version, diagnostics: diags)
    }

    // MARK: LSP Diagnostics

    func lspDiagnostics(for source: String) -> [LSPDiagnostic] {
        do {
            let file = try UrkelParser.parse(source)
            let vDiags = UrkelValidator.validate(file)
            return vDiags.map { toLSPDiagnostic($0, source: source) }
        } catch let pe as UrkelParseError {
            let r = lspRange(line: pe.line, column: pe.column ?? 1, length: 1)
            return [LSPDiagnostic(range: r, severity: .error, source: "urkel", message: pe.message)]
        } catch {
            return [LSPDiagnostic(range: .zero, severity: .error, source: "urkel", message: error.localizedDescription)]
        }
    }

    func toLSPDiagnostic(_ d: UrkelValidation.Diagnostic, source: String) -> LSPDiagnostic {
        let r: LSPRange
        if let dr = d.range {
            r = LSPRange(
                start: Position(line: dr.start.line, character: dr.start.column),
                end:   Position(line: dr.end.line,   character: dr.end.column)
            )
        } else {
            r = findDiagnosticRange(message: d.message, in: source)
        }
        let severity: DiagnosticSeverity = d.severity == .error ? .error : .warning
        return LSPDiagnostic(range: r, severity: severity, source: "urkel", message: d.message)
    }

    func findDiagnosticRange(message: String, in source: String) -> LSPRange {
        // Try to locate the state/event name mentioned in the diagnostic
        let lines = source.components(separatedBy: "\n")
        var stateName: String? = nil

        if message.hasPrefix("Unresolved state reference: ") {
            stateName = String(message.dropFirst("Unresolved state reference: ".count))
        } else if message.hasPrefix("Duplicate state declaration: ") {
            stateName = String(message.dropFirst("Duplicate state declaration: ".count))
        } else if message.hasPrefix("Unreachable state: ") {
            stateName = String(message.dropFirst("Unreachable state: ".count))
        }

        if let name = stateName {
            for (lineIdx, line) in lines.enumerated() {
                if let r = line.range(of: name) {
                    let col = line.distance(from: line.startIndex, to: r.lowerBound)
                    let len = name.count
                    return LSPRange(
                        start: Position(line: lineIdx, character: col),
                        end:   Position(line: lineIdx, character: col + len)
                    )
                }
            }
        }
        return .zero
    }

    // MARK: Completion

    func completionItems(for source: String, position: Position) -> [CompletionItem] {
        let lines = source.components(separatedBy: "\n")
        guard position.line < lines.count else { return [] }
        let line = lines[position.line]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        var items: [CompletionItem] = []

        // Always add keyword suggestions
        if trimmed.isEmpty || trimmed.hasPrefix("@") {
            items += [
                CompletionItem(label: "machine",      kind: .keyword, detail: "Machine declaration"),
                CompletionItem(label: "@states",      kind: .keyword, detail: "States block"),
                CompletionItem(label: "@transitions", kind: .keyword, detail: "Transitions block"),
                CompletionItem(label: "@import",      kind: .keyword, detail: "Import declaration"),
                CompletionItem(label: "@entry",       kind: .keyword, detail: "Entry hook"),
                CompletionItem(label: "@exit",        kind: .keyword, detail: "Exit hook"),
            ]
        }

        // State keywords (in states block)
        if isInsideStatesBlock(lines: lines, lineIndex: position.line) {
            items += [
                CompletionItem(label: "init",  kind: .keyword, detail: "Initial state"),
                CompletionItem(label: "state", kind: .keyword, detail: "Regular state"),
                CompletionItem(label: "final", kind: .keyword, detail: "Terminal state"),
            ]
        }

        // Inside transitions block: suggest states + events
        if isInsideTransitionsBlock(lines: lines, lineIndex: position.line) {
            items += [
                CompletionItem(label: "init",  kind: .keyword, detail: "Initial state"),
                CompletionItem(label: "state", kind: .keyword, detail: "Regular state"),
                CompletionItem(label: "final", kind: .keyword, detail: "Terminal state"),
            ]

            // State names from best-effort parse
            let file = try? UrkelParser.parse(source)
            let stateNames = file?.simpleStates.map(\.name) ?? bestEffortStateNames(in: lines)
            for name in stateNames {
                items.append(CompletionItem(label: name, kind: .struct, detail: "State"))
            }

            // Event names from existing transitions
            if let file {
                let eventNames = Set(file.transitionStmts.compactMap { t -> String? in
                    if case .event(let e) = t.event { return e.name }
                    return nil
                })
                for name in eventNames {
                    items.append(CompletionItem(label: name, kind: .event, detail: "Transition event"))
                }
            }

            // Hardcoded example event for new machines
            items.append(CompletionItem(label: "start", kind: .event, detail: "Example event"))
        }

        return deduplicatedCompletionItems(items)
    }

    func isInsideStatesBlock(lines: [String], lineIndex: Int) -> Bool {
        var inStates = false
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "@states" || t.hasPrefix("@states ") { inStates = true; continue }
            if t == "@transitions" || t.hasPrefix("@transitions ") { inStates = false; continue }
            if t == "@invariants" { inStates = false; continue }
            if i == lineIndex { return inStates }
        }
        return false
    }

    func isInsideTransitionsBlock(lines: [String], lineIndex: Int) -> Bool {
        var inTransitions = false
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "@transitions" || t.hasPrefix("@transitions ") { inTransitions = true; continue }
            if t == "@states" || t.hasPrefix("@states ") { inTransitions = false; continue }
            if t == "@invariants" { inTransitions = false; continue }
            if i == lineIndex { return inTransitions }
        }
        return false
    }

    func bestEffortStateNames(in lines: [String]) -> [String] {
        var names: [String] = []
        var inStates = false
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == "@states" { inStates = true; continue }
            if t.hasPrefix("@") { inStates = false; continue }
            if inStates {
                let words = t.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if let kind = words.first, (kind == "init" || kind == "state" || kind == "final"),
                   let name = words.dropFirst().first {
                    names.append(name)
                }
            }
        }
        return names
    }

    func deduplicatedCompletionItems(_ items: [CompletionItem]) -> [CompletionItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.label).inserted }
    }

    // MARK: Hover

    func hoverInfo(in source: String, position: Position) -> HoverResponse {
        let lines = source.components(separatedBy: "\n")
        guard position.line < lines.count else { return nil }
        let line = lines[position.line]
        // Try exact position first, then scan nearby for a word
        let word = wordAt(character: position.character, in: line)
            ?? wordNear(character: position.character, in: line)

        let file = try? UrkelParser.parse(source)

        if let word {
            if word == "machine" {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                let name = parts.count > 1 ? parts[1] : "Unknown"
                return Hover(contents: "Urkel machine `\(name)`.")
            }

            if let state = file?.simpleStates.first(where: { $0.name == word }) {
                let kind: String
                switch state.kind {
                case .`init`: kind = "initial"
                case .state:  kind = "state"
                case .final:  kind = "terminal"
                }
                return Hover(contents: "Urkel \(kind) state `\(state.name)`.",
                             range: findWordRange(in: source, lines: lines, lineIdx: position.line, word: word))
            }

            if let t = file?.transitionStmts.first(where: {
                if case .event(let e) = $0.event { return e.name == word }
                return false
            }) {
                if case .event(let e) = t.event {
                    let from: String
                    switch t.source {
                    case .state(let r): from = r.name
                    case .wildcard: from = "*"
                    }
                    let to = t.destination?.name ?? "(no destination)"
                    return Hover(
                        contents: "Transition event `\(e.name)` from `\(from)` to `\(to)`.",
                        range: findWordRange(in: source, lines: lines, lineIdx: position.line, word: word)
                    )
                }
            }

            if word == "@states" { return Hover(contents: "Declares the machine states section.") }
            if word == "@transitions" { return Hover(contents: "Declares the machine transitions section.") }
        }

        // Fallback: if on a transition line, return info about that transition
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("->"), let t = file?.transitionStmts.first {
            let from: String
            switch t.source {
            case .state(let r): from = r.name
            case .wildcard: from = "*"
            }
            let event: String
            if case .event(let e) = t.event { event = e.name } else { event = "event" }
            let to = t.destination?.name ?? "(no destination)"
            return Hover(
                contents: "Transition `\(from)` → `\(event)` → `\(to)`.",
                range: LSPRange(
                    start: Position(line: position.line, character: 0),
                    end: Position(line: position.line, character: line.count)
                )
            )
        }

        if let word {
            return Hover(contents: "Urkel symbol `\(word)`.")
        }
        return nil
    }

    func wordNear(character: Int, in line: String) -> String? {
        // Scan right for nearest word character
        var pos = character
        while pos < line.count {
            let idx = line.index(line.startIndex, offsetBy: pos)
            if line[idx].isLetter || line[idx].isNumber || line[idx] == "_" {
                return wordAt(character: pos, in: line)
            }
            pos += 1
        }
        // Scan left
        pos = character - 1
        while pos >= 0 {
            let idx = line.index(line.startIndex, offsetBy: pos)
            if line[idx].isLetter || line[idx].isNumber || line[idx] == "_" {
                return wordAt(character: pos, in: line)
            }
            pos -= 1
        }
        return nil
    }

    func wordAt(character: Int, in line: String) -> String? {
        guard character <= line.count else { return nil }
        let chars = Array(line)
        var pos = min(character, chars.count - 1)
        // Scan forward past whitespace/operators to find a word character
        while pos < chars.count && !chars[pos].isLetter && !chars[pos].isNumber && chars[pos] != "_" && chars[pos] != "@" {
            pos += 1
        }
        guard pos < chars.count else { return nil }
        var start = pos
        var end = pos
        while start > 0 {
            let prev = start - 1
            if chars[prev].isLetter || chars[prev].isNumber || chars[prev] == "_" || chars[prev] == "@" {
                start = prev
            } else { break }
        }
        while end < chars.count {
            if chars[end].isLetter || chars[end].isNumber || chars[end] == "_" {
                end += 1
            } else { break }
        }
        let word = String(chars[start..<end])
        return word.isEmpty ? nil : word
    }

    func findWordRange(in source: String, lines: [String], lineIdx: Int, word: String) -> LSPRange? {
        guard lineIdx < lines.count, let r = lines[lineIdx].range(of: word) else { return nil }
        let col = lines[lineIdx].distance(from: lines[lineIdx].startIndex, to: r.lowerBound)
        return LSPRange(
            start: Position(line: lineIdx, character: col),
            end:   Position(line: lineIdx, character: col + word.count)
        )
    }

    func findWordRange(in source: String, word: String) -> LSPRange? {
        let lines = source.components(separatedBy: "\n")
        for (lineIdx, line) in lines.enumerated() {
            if let r = line.range(of: word) {
                let col = line.distance(from: line.startIndex, to: r.lowerBound)
                return LSPRange(
                    start: Position(line: lineIdx, character: col),
                    end:   Position(line: lineIdx, character: col + word.count)
                )
            }
        }
        return nil
    }

    // MARK: Semantic Tokens

    func buildSemanticTokens(for source: String) -> [SemanticToken] {
        let lines = source.components(separatedBy: "\n")
        var tokens: [SemanticToken] = []

        func addToken(line: Int, col: Int, length: Int, kind: TokenKind) {
            tokens.append(SemanticToken(
                line: UInt32(line), char: UInt32(col),
                length: UInt32(length), type: UInt32(kind.rawValue)
            ))
        }

        let keywords = ["machine", "@states", "@transitions", "@import", "@entry", "@exit",
                        "init", "state", "final", "always", "after"]

        for (lineIdx, rawLine) in lines.enumerated() {
            let t = rawLine.trimmingCharacters(in: .whitespaces)

            // Comments
            if t.hasPrefix("#") {
                let col = rawLine.distance(from: rawLine.startIndex, to: rawLine.firstIndex(of: "#")!)
                addToken(line: lineIdx, col: col, length: t.count, kind: .comment)
                continue
            }

            // Keywords
            for kw in keywords {
                if t.hasPrefix(kw) {
                    if let r = rawLine.range(of: kw) {
                        let col = rawLine.distance(from: rawLine.startIndex, to: r.lowerBound)
                        addToken(line: lineIdx, col: col, length: kw.count, kind: .keyword)
                    }
                }
            }

            // Machine name
            if t.hasPrefix("machine ") {
                let parts = t.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2, let r = rawLine.range(of: parts[1]) {
                    let col = rawLine.distance(from: rawLine.startIndex, to: r.lowerBound)
                    addToken(line: lineIdx, col: col, length: parts[1].count, kind: .namespace)
                }
            }
        }

        return tokens
    }

    // MARK: Range helpers

    func lspRange(line: Int, column: Int, length: Int = 1) -> LSPRange {
        LSPRange(
            start: Position(line: max(line - 1, 0), character: max(column - 1, 0)),
            end:   Position(line: max(line - 1, 0), character: max(column - 1, 0) + length)
        )
    }

    func fullDocumentRange(for source: String) -> LSPRange {
        let lines = source.components(separatedBy: "\n")
        let lastLine = max(lines.count - 1, 0)
        let lastChar = lines.last?.count ?? 0
        return LSPRange(
            start: Position(line: 0, character: 0),
            end:   Position(line: lastLine, character: lastChar)
        )
    }

    // MARK: Quick fix helpers

    func findStateKindRange(in source: String, stateName: String) -> LSPRange? {
        let lines = source.components(separatedBy: "\n")
        for (lineIdx, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("state \(stateName)") || t.hasPrefix("init \(stateName)") || t.hasPrefix("final \(stateName)") {
                // Find "state" keyword position
                if let r = line.range(of: "state") {
                    let col = line.distance(from: line.startIndex, to: r.lowerBound)
                    return LSPRange(
                        start: Position(line: lineIdx, character: col),
                        end:   Position(line: lineIdx, character: col + 5)
                    )
                }
            }
        }
        return nil
    }

    // MARK: Levenshtein distance for typo fixes

    func closestMatch(to word: String, in candidates: [String]) -> String? {
        guard !candidates.isEmpty else { return nil }
        let threshold = max(word.count * 2 / 3, 2)
        return candidates
            .map { ($0, levenshtein(word, $0)) }
            .filter { $0.1 <= threshold }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    func levenshtein(_ s: String, _ t: String) -> Int {
        let sArr = Array(s), tArr = Array(t)
        let m = sArr.count, n = tArr.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        for i in 1...m {
            for j in 1...n {
                if sArr[i-1] == tArr[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        return dp[m][n]
    }
}

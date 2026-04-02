// EBNF: SimpleState   ::= {WS} StateKind ["(" ParameterList ")"] {WS} Identifier [{WS} HistoryModifier] {WS}
// EBNF: StateKind     ::= "init" | "state" | "final"
// EBNF: HistoryModifier ::= "@history" ["(" "deep" ")"]

import Parsing
import UrkelAST

/// Parses a simple state declaration line (already trimmed of outer whitespace).
struct SimpleStateDeclParser: Parser {
    let lineNum: Int

    func parse(_ input: inout Substring) throws -> SimpleStateDecl? {
        let trimmed = String(input).trimmingCharacters(in: .whitespaces)

        // init state
        if trimmed.hasPrefix("init") {
            let after = trimmed.dropFirst(4)
            if after.isEmpty || !after.first!.isLetter && after.first! != "_" {
                input = input[input.endIndex...]
                return try parseInitOrFinal(trimmed, kind: .`init`)
            }
        }
        // final state
        if trimmed.hasPrefix("final") {
            let after = trimmed.dropFirst(5)
            if after.isEmpty || !after.first!.isLetter && after.first! != "_" {
                input = input[input.endIndex...]
                return try parseInitOrFinal(trimmed, kind: .final)
            }
        }
        // state keyword
        if trimmed.hasPrefix("state ") || trimmed == "state" || trimmed.hasPrefix("state(") {
            // Reject compound openers (handled separately)
            if trimmed.hasSuffix("{") { return nil }
            input = input[input.endIndex...]
            return try parseRegularState(trimmed)
        }

        return nil
    }

    private func parseInitOrFinal(_ trimmed: String, kind: StateKind) throws -> SimpleStateDecl {
        let keyword = kind.rawValue
        var rest = String(trimmed.dropFirst(keyword.count)).trimmingCharacters(in: .whitespaces)

        var params: [Parameter] = []
        if rest.hasPrefix("(") {
            var s = rest[...]
            params = try ParameterListParser().parse(&s)
            rest = String(s).trimmingCharacters(in: .whitespaces)
        }

        let parts = rest.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let name = parts.first, !name.isEmpty else {
            throw UrkelParseError(message: "Expected state name after '\(keyword)'", line: lineNum)
        }

        var history: HistoryModifier? = nil
        if rest.contains("@history") {
            history = rest.contains("(deep)") ? .deep : .shallow
        }

        return SimpleStateDecl(kind: kind, params: params, name: name, history: history)
    }

    private func parseRegularState(_ trimmed: String) throws -> SimpleStateDecl {
        var rest = String(trimmed.dropFirst("state".count)).trimmingCharacters(in: .whitespaces)

        var params: [Parameter] = []
        // state(params) Name — params before name
        if rest.hasPrefix("(") {
            var s = rest[...]
            params = try ParameterListParser().parse(&s)
            rest = String(s).trimmingCharacters(in: .whitespaces)
        }

        // Parse name
        let nameEnd = rest.firstIndex(where: { c in
            !c.isLetter && !c.isNumber && c != "_"
        }) ?? rest.endIndex
        let name = String(rest[..<nameEnd])
        guard !name.isEmpty else {
            throw UrkelParseError(message: "Expected state name after 'state'", line: lineNum)
        }
        rest = String(rest[nameEnd...]).trimmingCharacters(in: .whitespaces)

        // state Name(params) — params after name (legacy syntax)
        if params.isEmpty && rest.hasPrefix("(") {
            var s = rest[...]
            params = try ParameterListParser().parse(&s)
            rest = String(s).trimmingCharacters(in: .whitespaces)
        }

        var history: HistoryModifier? = nil
        if rest.hasPrefix("@history") {
            history = rest.contains("(deep)") ? .deep : .shallow
        }

        return SimpleStateDecl(kind: .state, params: params, name: name, history: history)
    }
}

// EBNF: GuardClause ::= "[" {WS} ("else" | ["!"] Identifier) {WS} "]"

import Parsing
import UrkelAST

/// Parses a guard clause: "[guardName]", "[!guardName]", or "[else]".
struct GuardClauseParser: Parser {
    func parse(_ input: inout Substring) throws -> GuardClause {
        guard input.first == "[" else {
            throw ParseFailure.expected("'[' for guard clause")
        }
        guard let endIdx = input.firstIndex(of: "]") else {
            throw ParseFailure.message("Expected ']' to close guard clause")
        }
        let after = input.index(after: input.startIndex)
        let content = String(input[after..<endIdx]).trimmingCharacters(in: .whitespaces)
        input = input[input.index(after: endIdx)...]

        if content == "else" {
            return .else
        } else if content.hasPrefix("!") {
            return .negated(String(content.dropFirst()))
        } else {
            return .named(content)
        }
    }
}

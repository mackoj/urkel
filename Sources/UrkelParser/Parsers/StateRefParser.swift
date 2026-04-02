// EBNF: StateRef ::= Identifier {"." Identifier}

import Parsing
import UrkelAST

/// Parses a dot-joined state reference, e.g. "Active.Playing".
struct StateRefParser: Parser {
    func parse(_ input: inout Substring) throws -> StateRef {
        let original = input
        // Consume letters, digits, underscores, and dots
        let end = input.firstIndex(where: {
            !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != "."
        }) ?? input.endIndex
        let raw = String(input[..<end])
        guard !raw.isEmpty, raw.first!.isLetter || raw.first! == "_" else {
            input = original
            throw ParseFailure.expected("state reference")
        }
        input = input[end...]
        let components = raw.components(separatedBy: ".")
        return StateRef(components)
    }
}

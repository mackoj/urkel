// EBNF: Identifier ::= (Letter | "_") {Letter | Digit | "_"}

import Parsing

/// Parses a bare identifier: starts with letter or "_", followed by alphanumeric/"_".
struct UrkelIdentifier: Parser {
    func parse(_ input: inout Substring) throws -> String {
        let original = input
        guard let first = input.first, first.isLetter || first == "_" else {
            throw ParseFailure.expected("identifier")
        }
        input.removeFirst()
        while let c = input.first, c.isLetter || c.isNumber || c == "_" {
            input.removeFirst()
        }
        return String(original[original.startIndex..<input.startIndex])
    }
}

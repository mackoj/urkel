// EBNF: Arrow ::= "->" | "-*>"

import Parsing
import UrkelAST

/// Parses an arrow: "->" (standard) or "-*>" (internal).
struct ArrowParser: Parser {
    func parse(_ input: inout Substring) throws -> Arrow {
        if input.hasPrefix("-*>") {
            input.removeFirst(3)
            return .internal
        }
        if input.hasPrefix("->") {
            input.removeFirst(2)
            return .standard
        }
        throw ParseFailure.expected("arrow '->' or '-*>'")
    }
}

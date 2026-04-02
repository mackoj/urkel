// EBNF: InlineWhitespace ::= (" " | "\t")+
// EBNF: OptionalWS       ::= (" " | "\t")*

import Parsing

/// Consumes one or more space/tab characters.
struct InlineWhitespace: Parser {
    func parse(_ input: inout Substring) throws {
        guard input.first == " " || input.first == "\t" else {
            throw ParseFailure.expected("inline whitespace")
        }
        input = input.drop(while: { $0 == " " || $0 == "\t" })
    }
}

/// Consumes zero or more space/tab characters (always succeeds).
struct OptionalWS: Parser {
    func parse(_ input: inout Substring) throws {
        input = input.drop(while: { $0 == " " || $0 == "\t" })
    }
}

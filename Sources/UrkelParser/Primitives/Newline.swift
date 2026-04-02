// EBNF: Newline ::= "\r\n" | "\n"

import Parsing

/// Consumes a single line ending ("\r\n" or "\n").
struct UrkelNewline: Parser {
    func parse(_ input: inout Substring) throws {
        if input.hasPrefix("\r\n") {
            input.removeFirst(2)
        } else if input.first == "\n" {
            input.removeFirst()
        } else {
            throw ParseFailure.expected("newline")
        }
    }
}

/// Consumes optional inline whitespace then a newline (end-of-line).
struct EndOfLine: Parser {
    func parse(_ input: inout Substring) throws {
        try? OptionalWS().parse(&input)
        if input.isEmpty { return }
        try UrkelNewline().parse(&input)
    }
}

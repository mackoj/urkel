// EBNF: TypeExpr ::= (any char except ")", ",", "\n", "\r")+
// TypeExpr stops at delimiter characters and has trailing whitespace trimmed.

import Parsing

/// Parses a type expression: consumes until ")", ",", "\n", or "\r".
/// The result is trimmed of trailing whitespace.
struct TypeExprParser: Parser {
    func parse(_ input: inout Substring) throws -> String {
        let result = input.prefix(while: { $0 != ")" && $0 != "," && $0 != "\n" && $0 != "\r" })
        guard !result.isEmpty else {
            throw ParseFailure.expected("type expression")
        }
        input = input.dropFirst(result.count)
        return String(result).trimmingCharacters(in: .whitespaces)
    }
}

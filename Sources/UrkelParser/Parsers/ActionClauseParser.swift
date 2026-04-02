// EBNF: ActionClause ::= "/" {WS} Identifier {"," {WS} Identifier}

import Parsing
import UrkelAST

/// Parses an action clause: "/ action1, action2".
struct ActionClauseParser: Parser {
    func parse(_ input: inout Substring) throws -> ActionClause {
        guard input.first == "/" else {
            throw ParseFailure.expected("'/' for action clause")
        }
        input.removeFirst()
        try? OptionalWS().parse(&input)
        let rest = String(input.prefix(while: { $0 != "\n" && $0 != "\r" }))
        input.removeFirst(rest.count)
        let actions = rest
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !actions.isEmpty else {
            throw ParseFailure.message("Expected action name after '/'")
        }
        return ActionClause(actions: actions)
    }
}

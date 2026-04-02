// EBNF: EntryExitDecl ::= {WS} ("@entry" | "@exit") WS StateRef {WS} "/" {WS} ActionList {WS}

import Parsing
import UrkelAST

/// Parses an @entry or @exit hook from the full trimmed line.
struct EntryExitDeclParser: Parser {
    let lineNum: Int

    func parse(_ input: inout Substring) throws -> EntryExitDecl {
        try? OptionalWS().parse(&input)

        let isEntry: Bool
        if input.hasPrefix("@entry") {
            isEntry = true
            input.removeFirst(6)
        } else if input.hasPrefix("@exit") {
            isEntry = false
            input.removeFirst(5)
        } else {
            throw ParseFailure.expected("'@entry' or '@exit'")
        }

        // Consume whitespace between keyword and state name
        try? OptionalWS().parse(&input)
        // Also handle multiple spaces (the original tests use "  @exit  Running")
        input = input.drop(while: { $0 == " " || $0 == "\t" })

        let rest = String(input).trimmingCharacters(in: .whitespaces)
        input = input[input.endIndex...]

        let slashParts = rest.components(separatedBy: "/")
        guard slashParts.count >= 2 else {
            throw UrkelParseError(
                message: "Expected '/' in @\(isEntry ? "entry" : "exit") hook",
                line: lineNum
            )
        }
        let stateName = slashParts[0].trimmingCharacters(in: .whitespaces)
        let actionStr = slashParts[1...].joined(separator: "/").trimmingCharacters(in: .whitespaces)
        let actions = actionStr
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return EntryExitDecl(
            hook: isEntry ? .entry : .exit,
            state: StateRef(stateName.components(separatedBy: ".")),
            actions: actions
        )
    }
}

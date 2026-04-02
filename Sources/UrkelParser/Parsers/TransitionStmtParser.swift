// EBNF: TransitionStmt ::= {WS} Source {WS} Arrow {WS} EventOrTimer
//                          [{WS} GuardClause]
//                          [{WS} "->" {WS} StateRef [{WS} ForkClause]]
//                          [{WS} ActionClause] {WS} Newline
// Source ::= StateRef | "*"

import Parsing
import UrkelAST

/// Parses a single transition statement line.
/// Returns `nil` if the line does not start with a recognizable source.
struct TransitionStmtParser: Parser {
    let lineNum: Int

    func parse(_ input: inout Substring) throws -> TransitionStmt? {
        let original = input
        try? OptionalWS().parse(&input)

        // Parse source: wildcard "*" or a state name
        let source: TransitionSource
        if input.first == "*" {
            input.removeFirst()
            source = .wildcard
        } else {
            // Try to parse state ref
            let end = input.firstIndex(where: { c in
                !c.isLetter && !c.isNumber && c != "_" && c != "."
            }) ?? input.endIndex
            let name = String(input[..<end])
            guard !name.isEmpty, name.first!.isLetter || name.first! == "_" else {
                input = original
                return nil
            }
            input = input[end...]
            source = .state(StateRef(name.components(separatedBy: ".")))
        }

        try? OptionalWS().parse(&input)

        // Must have an arrow after source
        let arrow: Arrow
        do {
            arrow = try ArrowParser().parse(&input)
        } catch {
            input = original
            return nil
        }
        try? OptionalWS().parse(&input)

        // Must have event/timer/always after arrow
        guard !input.isEmpty && input.first != "\n" && input.first != "\r" else {
            throw UrkelParseError(
                message: "Transition must follow: Source -> event -> Dest",
                line: lineNum
            )
        }

        let event = try EventOrTimerParser(lineNum: lineNum).parse(&input)
        try? OptionalWS().parse(&input)

        // Optional guard clause [...]
        var guardClause: GuardClause? = nil
        if input.first == "[" {
            guardClause = try GuardClauseParser().parse(&input)
            try? OptionalWS().parse(&input)
        }

        // Optional -> Destination [=> Fork]
        var destination: StateRef? = nil
        var forkClause: ForkClause? = nil
        if input.hasPrefix("->") {
            input.removeFirst(2)
            try? OptionalWS().parse(&input)
            let destEnd = input.firstIndex(where: { c in
                !c.isLetter && !c.isNumber && c != "_" && c != "."
            }) ?? input.endIndex
            let destName = String(input[..<destEnd])
            if !destName.isEmpty {
                destination = StateRef(destName.components(separatedBy: "."))
                input = input[destEnd...]
            }
            try? OptionalWS().parse(&input)
            if input.hasPrefix("=>") {
                forkClause = try ForkClauseParser().parse(&input)
                try? OptionalWS().parse(&input)
            }
        }

        // Optional / action1, action2
        var actionClause: ActionClause? = nil
        if input.first == "/" {
            actionClause = try ActionClauseParser().parse(&input)
        }

        return TransitionStmt(
            source: source,
            arrow: arrow,
            event: event,
            guard: guardClause,
            destination: destination,
            fork: forkClause,
            action: actionClause
        )
    }
}

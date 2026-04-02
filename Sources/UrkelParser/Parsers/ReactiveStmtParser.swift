// EBNF: ReactiveStmt  ::= {WS} "@on" WS ReactiveSource ["," Identifier] {WS} Arrow {WS}
//                          (StateRef [ActionClause] | ActionClause) {WS}
// ReactiveSource ::= (Identifier "." Identifier | Identifier) "::" (Identifier | "init" | "final" | "*")

import Parsing
import UrkelAST

/// Parses an "@on" reactive transition statement.
struct ReactiveStmtParser: Parser {
    let lineNum: Int

    func parse(_ input: inout Substring) throws -> ReactiveStmt? {
        let original = input
        try? OptionalWS().parse(&input)

        guard input.hasPrefix("@on") else {
            input = original
            return nil
        }
        input.removeFirst(3)
        try InlineWhitespace().parse(&input)

        // Parse ReactiveSource: target::state
        guard let colonColonRange = input.range(of: "::") else {
            throw UrkelParseError(message: "Expected '::' in @on source", line: lineNum)
        }
        let targetStr = String(input[..<colonColonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        input = input[colonColonRange.upperBound...]

        let reactiveTarget: ReactiveTarget
        if targetStr.contains(".") {
            let parts = targetStr.components(separatedBy: ".")
            reactiveTarget = .region(parallel: parts[0], region: parts[1])
        } else {
            reactiveTarget = .machine(targetStr)
        }

        // Parse state identifier (or "*")
        let stateEnd = input.firstIndex(where: { c in
            !c.isLetter && !c.isNumber && c != "_" && c != "*"
        }) ?? input.endIndex
        let stateStr = String(input[..<stateEnd])
        input = input[stateEnd...]
        try? OptionalWS().parse(&input)

        let reactiveState: ReactiveState
        switch stateStr {
        case "init":  reactiveState = .`init`
        case "final": reactiveState = .final
        case "*":     reactiveState = .any
        default:      reactiveState = .named(stateStr)
        }

        // Optional ", ownState"
        var ownState: String? = nil
        if input.first == "," {
            input.removeFirst()
            try? OptionalWS().parse(&input)
            let j = input.firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" }) ?? input.endIndex
            ownState = String(input[..<j])
            input = input[j...]
            try? OptionalWS().parse(&input)
        }

        // Arrow
        let arrow: Arrow
        do {
            arrow = try ArrowParser().parse(&input)
        } catch {
            throw UrkelParseError(message: "Expected '->' in @on statement", line: lineNum)
        }
        try? OptionalWS().parse(&input)

        // Optional destination state ref
        var destination: StateRef? = nil
        let destEnd = input.firstIndex(where: { c in
            !c.isLetter && !c.isNumber && c != "_" && c != "."
        }) ?? input.endIndex
        let destName = String(input[..<destEnd])
        if !destName.isEmpty {
            destination = StateRef(destName.components(separatedBy: "."))
            input = input[destEnd...]
        }
        try? OptionalWS().parse(&input)

        // Optional action clause
        var actionClause: ActionClause? = nil
        if input.first == "/" {
            actionClause = try ActionClauseParser().parse(&input)
        }

        return ReactiveStmt(
            source: ReactiveSource(target: reactiveTarget, state: reactiveState),
            ownState: ownState,
            arrow: arrow,
            destination: destination,
            action: actionClause
        )
    }
}

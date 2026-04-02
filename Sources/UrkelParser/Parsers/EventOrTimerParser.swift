// EBNF: EventOrTimer ::= "always"
//                       | "after" "(" Duration ["," ParameterList] ")"
//                       | Identifier ["(" ParameterList ")"]

import Parsing
import UrkelAST

/// Parses the event/timer portion of a transition: "always", "after(...)", or "eventName(...)".
struct EventOrTimerParser: Parser {
    let lineNum: Int

    func parse(_ input: inout Substring) throws -> EventOrTimer {
        // "always" keyword
        if input.hasPrefix("always") {
            let idx6 = input.index(input.startIndex, offsetBy: min(6, input.count))
            let nextChar: Character = idx6 < input.endIndex ? input[idx6] : " "
            if nextChar.isWhitespace || idx6 == input.endIndex || nextChar == "[" || nextChar == "/" {
                input.removeFirst(6)
                return .always
            }
        }

        // "after(..." timer
        if input.hasPrefix("after") {
            let idx5 = input.index(input.startIndex, offsetBy: min(5, input.count))
            let afterChar: Character = idx5 < input.endIndex ? input[idx5] : " "
            if afterChar == "(" || afterChar == " " {
                return try parseTimer(&input)
            }
        }

        // regular event name
        return try parseEvent(&input)
    }

    private func parseTimer(_ input: inout Substring) throws -> EventOrTimer {
        guard input.hasPrefix("after") else {
            throw UrkelParseError(message: "Expected 'after'", line: lineNum)
        }
        input.removeFirst(5)
        try? OptionalWS().parse(&input)
        guard input.first == "(" else {
            throw UrkelParseError(message: "Expected '(' after 'after'", line: lineNum)
        }

        // Find matching closing paren
        var depth = 0
        var contentStart: Substring.Index? = nil
        var contentEnd: Substring.Index? = nil
        var afterIdx: Substring.Index = input.startIndex

        for idx in input.indices {
            let c = input[idx]
            if c == "(" {
                depth += 1
                if depth == 1 { contentStart = input.index(after: idx) }
            } else if c == ")" {
                depth -= 1
                if depth == 0 {
                    contentEnd = idx
                    afterIdx = input.index(after: idx)
                    break
                }
            }
        }
        guard let cs = contentStart, let ce = contentEnd else {
            throw UrkelParseError(message: "Unbalanced '(' in after()", line: lineNum)
        }
        let content = String(input[cs..<ce]).trimmingCharacters(in: .whitespaces)
        input = input[afterIdx...]

        // Split: "100ms" or "100ms, label: Type"
        let commaIdx = content.firstIndex(of: ",")
        let durationStr = commaIdx.map {
            String(content[..<$0]).trimmingCharacters(in: .whitespaces)
        } ?? content

        var durationInput = durationStr[...]
        let duration = (try? DurationParser().parse(&durationInput)) ?? Duration(value: 1, unit: .s)

        var timerParams: [Parameter] = []
        if let ci = commaIdx {
            let paramStr = "(" + String(content[content.index(after: ci)...]).trimmingCharacters(in: .whitespaces) + ")"
            var ps = paramStr[...]
            timerParams = (try? ParameterListParser().parse(&ps)) ?? []
        }
        return .timer(TimerDecl(duration: duration, params: timerParams))
    }

    private func parseEvent(_ input: inout Substring) throws -> EventOrTimer {
        let nameEnd = input.firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" }) ?? input.endIndex
        let name = String(input[..<nameEnd])
        guard !name.isEmpty else {
            throw UrkelParseError(message: "Expected event name", line: lineNum)
        }
        input = input[nameEnd...]
        try? OptionalWS().parse(&input)
        var params: [Parameter] = []
        if input.first == "(" {
            params = try ParameterListParser().parse(&input)
        }
        return .event(EventDecl(name: name, params: params))
    }
}

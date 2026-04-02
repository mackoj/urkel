// EBNF: Duration     ::= Number ("ms" | "s" | "min")
// EBNF: DurationUnit ::= "ms" | "s" | "min"

import Parsing
import UrkelAST

/// Parses a duration literal: "30s", "500ms", "1.5min".
struct DurationParser: Parser {
    func parse(_ input: inout Substring) throws -> Duration {
        // Consume numeric characters (digits and ".")
        let numEnd = input.firstIndex(where: { !$0.isNumber && $0 != "." }) ?? input.endIndex
        let numStr = String(input[..<numEnd])
        guard let value = Double(numStr), !numStr.isEmpty else {
            throw ParseFailure.expected("numeric duration value")
        }
        input = input[numEnd...]

        if input.hasPrefix("min") {
            input.removeFirst(3)
            return Duration(value: value, unit: .min)
        }
        if input.hasPrefix("ms") {
            input.removeFirst(2)
            return Duration(value: value, unit: .ms)
        }
        if input.hasPrefix("s") {
            input.removeFirst(1)
            return Duration(value: value, unit: .s)
        }
        throw ParseFailure.expected("duration unit ('ms', 's', or 'min')")
    }
}

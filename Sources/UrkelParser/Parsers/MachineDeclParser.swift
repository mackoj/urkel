// EBNF: MachineName ::= {WS} "machine" WS Identifier [":" Identifier] {WS}

import Parsing
import UrkelAST

/// Parses the machine declaration name and optional context type.
/// Call this with the content AFTER stripping "machine" from the start of the line.
struct MachineDeclParser: Parser {
    let fallback: String?

    func parse(_ input: inout Substring) throws -> (name: String, contextType: String?) {
        var rest = String(input).trimmingCharacters(in: .whitespaces)
        input = input[input.endIndex...]  // consume all

        if rest.isEmpty {
            return (fallback ?? "Machine", nil)
        }
        if let colonIdx = rest.firstIndex(of: ":") {
            let name = String(rest[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let ctx  = String(rest[rest.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            return (
                name.isEmpty ? (fallback ?? "Machine") : name,
                ctx.isEmpty  ? nil : ctx
            )
        }
        let name = rest.trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? (fallback ?? "Machine") : name, nil)
    }
}

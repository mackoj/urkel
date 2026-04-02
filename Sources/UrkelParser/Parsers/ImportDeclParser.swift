// EBNF: ImportDecl ::= {WS} "@import" WS Identifier ["from" Identifier] {WS}

import Parsing
import UrkelAST

/// Parses an import declaration from the content AFTER "@import ".
struct ImportDeclParser: Parser {
    let lineNum: Int

    func parse(_ input: inout Substring) throws -> ImportDecl {
        let rest = String(input).trimmingCharacters(in: .whitespaces)
        input = input[input.endIndex...]
        let parts = rest.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let name = parts.first, !name.isEmpty else {
            throw UrkelParseError(message: "Expected import name", line: lineNum)
        }
        var from: String? = nil
        if parts.count >= 3, parts[1] == "from" { from = parts[2] }
        return ImportDecl(name: name, from: from)
    }
}

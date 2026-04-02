// EBNF: ForkClause    ::= "=>" {WS} Identifier ".init" ["(" ForkBindingList ")"]
// EBNF: ForkBinding   ::= Identifier ":" Identifier

import Parsing
import UrkelAST

/// Parses a fork clause: "=> MachineName.init" or "=> MachineName.init(param: src)".
struct ForkClauseParser: Parser {
    func parse(_ input: inout Substring) throws -> ForkClause {
        guard input.hasPrefix("=>") else {
            throw ParseFailure.expected("'=>' for fork clause")
        }
        input.removeFirst(2)
        try? OptionalWS().parse(&input)

        // Consume the machine reference (e.g., "MachineName.init")
        let refEnd = input.firstIndex(where: { c in
            !c.isLetter && !c.isNumber && c != "_" && c != "."
        }) ?? input.endIndex
        let ref = String(input[..<refEnd])
        input = input[refEnd...]

        let machineName = ref.components(separatedBy: ".").first ?? ref

        var bindings: [ForkBinding] = []
        if input.first == "(" {
            let params = try ParameterListParser().parse(&input)
            bindings = params.map { ForkBinding(param: $0.label, source: $0.typeExpr) }
        }
        return ForkClause(machine: machineName, bindings: bindings)
    }
}

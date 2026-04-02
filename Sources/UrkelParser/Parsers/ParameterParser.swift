// EBNF: Parameter     ::= Identifier ":" TypeExpr
// EBNF: ParameterList ::= "(" Parameter {"," Parameter} ")"

import Parsing
import UrkelAST

/// Parses a single parameter: "label: TypeExpr".
/// The input must be the full parameter segment (e.g. "label: Result<A, B>"),
/// already extracted by ParameterListParser. Everything after the first ":" at
/// depth 0 is taken as the type expression — no secondary tokenisation needed.
struct ParameterParser: Parser {
    func parse(_ input: inout Substring) throws -> Parameter {
        // Find ":" at depth 0, honouring all bracket kinds
        var depth = 0
        var colonIdx: Substring.Index? = nil
        var idx = input.startIndex
        while idx < input.endIndex {
            switch input[idx] {
            case "(", "[", "{", "<": depth += 1
            case ")", "]", "}", ">": if depth > 0 { depth -= 1 }
            case ":" where depth == 0: colonIdx = idx
            default: break
            }
            if colonIdx != nil { break }
            idx = input.index(after: idx)
        }
        guard let ci = colonIdx else {
            throw ParseFailure.message("Expected ':' in parameter")
        }
        let label    = String(input[..<ci]).trimmingCharacters(in: .whitespaces)
        // Take everything after ":" — ParameterListParser already gave us only this segment
        let typeExpr = String(input[input.index(after: ci)...]).trimmingCharacters(in: .whitespaces)
        input = input[input.endIndex...]   // consume full segment
        return Parameter(label: label, typeExpr: typeExpr)
    }
}

/// Parses a parenthesised parameter list: "(label: TypeExpr, ...)".
/// Returns the parameters and leaves the rest of the input after ")".
struct ParameterListParser: Parser {
    func parse(_ input: inout Substring) throws -> [Parameter] {
        guard input.first == "(" else {
            throw ParseFailure.expected("'(' for parameter list")
        }
        var params: [Parameter] = []
        var i = input.index(after: input.startIndex)
        var stack: [Character] = ["("]
        var current: Substring = input[i...]

        while i < input.endIndex {
            let c = input[i]
            switch c {
            case "(": stack.append("(")
            case "[": stack.append("[")
            case "{": stack.append("{")
            case "<": stack.append("<")
            case ")":
                if stack.last == "(" { stack.removeLast() }
                if stack.isEmpty {
                    // parse last segment
                    let seg = String(current[..<i]).trimmingCharacters(in: .whitespaces)
                    if !seg.isEmpty {
                        var s = seg[...]
                        params.append(try ParameterParser().parse(&s))
                    }
                    input = input[input.index(after: i)...]
                    return params
                }
            case ">":
                if stack.last == "<" { stack.removeLast() }
            case "]":
                if stack.last == "[" { stack.removeLast() }
            case "}":
                if stack.last == "{" { stack.removeLast() }
            case "," where stack.count == 1:
                let seg = String(current[..<i]).trimmingCharacters(in: .whitespaces)
                if !seg.isEmpty {
                    var s = seg[...]
                    params.append(try ParameterParser().parse(&s))
                }
                let next = input.index(after: i)
                current = input[next...]
                i = next
                continue
            default: break
            }
            i = input.index(after: i)
        }
        throw ParseFailure.message("Unbalanced parentheses in parameter list")
    }
}

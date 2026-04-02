// EBNF: TriviaLine  ::= BlankLine | CommentLine | DocCommentLine
// EBNF: BlankLine   ::= {WS} "\n"
// EBNF: CommentLine ::= {WS} "#" {any} "\n"
// EBNF: DocCommentLine ::= {WS} "##" {any} "\n"  →  DocComment(text)

import Parsing
import UrkelAST

/// Parses "## text\n" and returns a DocComment, or nil for a plain comment/blank.
struct TriviaLine: Parser {
    func parse(_ input: inout Substring) throws -> DocComment? {
        let original = input
        try? OptionalWS().parse(&input)

        if input.hasPrefix("##") {
            input.removeFirst(2)
            // optional space then text
            let textContent = input.prefix(while: { $0 != "\n" && $0 != "\r" })
            let text = String(textContent).trimmingCharacters(in: .whitespaces)
            input.removeFirst(textContent.count)
            try? UrkelNewline().parse(&input)
            return DocComment(text: text)
        }

        if input.hasPrefix("#") {
            // plain comment — consume and discard
            input = input.drop(while: { $0 != "\n" && $0 != "\r" })
            try? UrkelNewline().parse(&input)
            return nil
        }

        if input.isEmpty || input.first == "\n" || input.first == "\r" {
            // blank line
            try? UrkelNewline().parse(&input)
            return nil
        }

        // Not a trivia line — restore and signal failure
        input = original
        throw ParseFailure.expected("trivia line")
    }
}

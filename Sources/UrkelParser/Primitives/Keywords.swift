// EBNF: Keywords ::= "machine" | "init" | "state" | "final" | "always" | "region" | "else"

import Parsing

/// Reserved keywords that cannot be used as plain identifiers.
enum Keywords {
    static let all: Set<String> = [
        "machine", "init", "state", "final", "always",
        "region", "else", "after", "from"
    ]
}

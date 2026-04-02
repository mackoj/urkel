// EBNF: InvariantsBlock ::= {WS} "@invariants" Newline
//                           {TriviaLine | InvariantDecl}
// InvariantDecl ::= {WS} ("reachable"|"unreachable") "(" ... ")" Newline
//                 | {WS} ("noDeadlock"|"deterministic"|"acyclic"|"allPathsReachFinal") Newline

import Parsing
import UrkelAST

// Invariants block parsing is handled inline in UrkelFileParser.swift.
// The existing parser ignores invariant line content (returns empty []).

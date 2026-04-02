// EBNF: TransitionsBlock ::= {WS} "@transitions" {WS} Newline
//                            {TriviaLine | TransitionStmt | ReactiveStmt}

import Parsing
import UrkelAST

// Transitions block parsing is handled inline in UrkelFileParser.swift
// This file exists for documentation purposes.
// See TransitionStmtParser and ReactiveStmtParser for line-level parsers.

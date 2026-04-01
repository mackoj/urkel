# US-2.2: States Block Parsers

## Objective

Implement the `swift-parsing` combinators that turn the `@states` block of a
`.urkel` file into an array of `StateDecl` AST nodes, covering simple states
(all three kinds with optional params and `@history`), compound states (nested
children with inner transitions), and the `ParameterList`/`Parameter` sub-rules.

## Background

The `@states` block is the declaration spine of every machine. It is parsed
independently of the `@transitions` block, so these parsers are a clean,
self-contained unit. The grammar rules handled here are the most structurally
varied: `init`, `state`, and `final` each carry optional parameter lists;
`state` can also open a `{ … }` compound block; `@history` is an optional
modifier. Getting these parsers right establishes the pattern every subsequent
parser story follows.

## Grammar Productions Covered

```ebnf
StatesBlock       ::= { Whitespace } "@states" { Whitespace } Newline
                      { TriviaLine | StateDecl }

StateDecl         ::= SimpleStateDecl | CompoundStateDecl

SimpleStateDecl   ::= { Whitespace } StateKind
                      [ "(" ParameterList ")" ]
                      { Whitespace } Identifier
                      [ { Whitespace } HistoryModifier ]
                      { Whitespace } Newline

StateKind         ::= "init" | "state" | "final"

HistoryModifier   ::= "@history" [ "(" "deep" ")" ]

CompoundStateDecl ::= { Whitespace } "state" { Whitespace } Identifier
                      [ { Whitespace } HistoryModifier ]
                      { Whitespace } "{" { Whitespace } Newline
                      { TriviaLine | SimpleStateDecl }
                      { TriviaLine | TransitionStmt }
                      { Whitespace } "}" { Whitespace } Newline

ParameterList     ::= Parameter { { Whitespace } "," { Whitespace } Parameter }
Parameter         ::= Identifier { Whitespace } ":" { Whitespace } TypeExpr
```

## Acceptance Criteria

* **Given** the text `"  init Idle\n"`, **when** parsed by `SimpleStateDeclParser`,
  **then** it returns `SimpleStateDecl(kind: .init, params: [], name: "Idle", history: nil)`.

* **Given** `"  init(directory: URL) Watching\n"`, **when** parsed,
  **then** `params == [Parameter(label: "directory", typeExpr: "URL")]`
  and `name == "Watching"`.

* **Given** `"  final(data: [String: Any]?) Done\n"`, **when** parsed,
  **then** `kind == .final` and `typeExpr == "[String: Any]?"`.

* **Given** `"  state Loaded(data: Data, source: URL)\n"`, **when** parsed (note: params come AFTER the name for `state` kind per grammar), 
  **then** `kind == .state`, `name == "Loaded"`, `params == [Parameter(label: "data", typeExpr: "Data"), Parameter(label: "source", typeExpr: "URL")]`.

* **Given** `"  state Active @history\n"`, **when** parsed,
  **then** `history == .shallow`.

* **Given** `"  state Active @history(deep)\n"`, **when** parsed,
  **then** `history == .deep`.

* **Given** a compound state block:
  ```
    state Playback {
      init Buffering
      state Playing
      final Stopped
      Buffering -> ready -> Playing
    }
  ```
  **when** parsed by `CompoundStateDeclParser`, **then** it returns a
  `CompoundStateDecl` with 3 children and 1 inner transition.

* **Given** a full `@states` block mixing trivia, simple states, and one
  compound state, **when** parsed by `StatesBlockParser`, **then** the
  resulting `[StateDecl]` has the correct count and ordering.

* **Given** `"  state"` (keyword used as state name), **when** parsed,
  **then** the parser fails with a meaningful error.

## Implementation Details

* Create `Sources/Urkel/Parser/States/`:
  - `ParameterParser.swift` — `Parameter` and `ParameterListParser`.
  - `StateKindParser.swift` — parses `"init"` | `"state"` | `"final"` into `StateKind`.
  - `HistoryModifierParser.swift` — `@history` and `@history(deep)`.
  - `SimpleStateDeclParser.swift`.
  - `CompoundStateDeclParser.swift` — note: inner `TransitionStmt` parsing uses
    a forward reference to the transitions parser from US-2.3; use a lazy/deferred
    combinator to avoid circular dependency.
  - `StatesBlockParser.swift` — the `@states` header + repeated `TriviaLine | StateDecl`.
* Source-range attachment: wrap each parser's output with a `WithRange` helper
  that records the `Substring` bounds before/after the parse and converts them to
  a `SourceRange` (using the line-offset index computed from the full input).
* Attach pending `[DocComment]` to each `StateDecl` from the preceding `TriviaLine`s.
* All parsers are composable via `swift-parsing`'s `Parse { }` result-builder DSL.
* Each file starts with `// EBNF: RuleName ::= …` linking to `grammar.ebnf`.

## Testing Strategy

* Create `Tests/UrkelTests/ParserTests/StatesBlockTests.swift`.
* Test each parser in isolation first, then compose:
  - `ParameterParser` — single param, multi-param, BYOT type with angle brackets.
  - `SimpleStateDeclParser` — all three state kinds × (no params, with params) × (no history, shallow, deep).
  - `CompoundStateDeclParser` — minimal (no inner transitions), with inner transitions.
  - `StatesBlockParser` — full block with mixed trivia, doc comments, simple, and compound states.
* Parse the `@states` section from the `FolderWatch` and `BluetoothBlender`
  example `.urkel` files; compare against the reference fixture ASTs from US-2.2.
* Assert that `range` is populated on every returned node (not `nil`).

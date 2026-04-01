# US-2.1: swift-parsing Integration & Lexical Primitives

## Objective

Add `pointfreeco/swift-parsing` as a package dependency and implement the
foundational lexical parsers that every higher-level grammar rule is built from:
whitespace, newlines, identifiers, keyword detection, BYOT type expressions, and
doc-comment capture. These primitives are the atoms — every subsequent parser
story composes them.

## Background

`swift-parsing` is a composable, bidirectional parser-combinator library for
Swift. It is chosen because:

1. **Bidirectionality** — parsers that conform to `ParserPrinter` can run in
   reverse, printing an AST back to text. This gives the auto-formatter (US-2.5)
   for free.
2. **Source tracking** — the library exposes `Substring` positions throughout,
   making it straightforward to map parse results to `SourceRange` values
   (US-2.3).
3. **Composability** — each EBNF rule becomes a Swift type, keeping the
   implementation a direct mirror of `grammar.ebnf`.
4. **Error quality** — failures produce structured context including the
   remaining input, enabling precise error messages for the LSP (Epic 6).

The lexical layer deals with characters and tokens only — no AST construction
happens here. These parsers are the workhorses called dozens of times per file.

## Grammar Productions Covered

```ebnf
Whitespace       ::= " " | "\t"
Newline          ::= "\n" | "\r\n"
BlankLine        ::= { Whitespace } Newline
CommentLine      ::= { Whitespace } "#"  { AnyExceptNewline } Newline
DocCommentLine   ::= { Whitespace } "##" { AnyExceptNewline } Newline
TriviaLine       ::= BlankLine | CommentLine | DocCommentLine
Identifier       ::= IdentStart { IdentCont }
IdentStart       ::= Letter | "_"
IdentCont        ::= Letter | Digit | "_"
TypeExpr         ::= TypeChar { TypeChar }
TypeChar         ::= any character except ")", ",", Newline
Keywords         ::= "machine" | "always" | "after" | "else"
                   | "@states" | "@transitions" | "@import" | "@parallel"
                   | "@entry" | "@exit" | "@on" | "@history"
                   | "init" | "state" | "final"
                   | "region" | "from" | "done"
```

## Acceptance Criteria

* **Given** `pointfreeco/swift-parsing` version `0.14.0` or later is added to
  `Package.swift`, **when** `swift package resolve` runs, **then** the package
  resolves without errors and the module is importable.

* **Given** the string `"  \t  "`, **when** parsed by `InlineWhitespace`,
  **then** it succeeds and the remaining input is empty.

* **Given** the string `"myState_2"`, **when** parsed by `UrkelIdentifier`,
  **then** it succeeds returning `"myState_2"`.

* **Given** the string `"42state"`, **when** parsed by `UrkelIdentifier`,
  **then** it fails (identifiers must start with a letter or `_`).

* **Given** the string `"always"`, **when** parsed by `UrkelIdentifier` and
  then validated by `KeywordCheck`, **then** the parse succeeds lexically but
  `KeywordCheck` flags it as a reserved keyword — callers that need a
  user-defined name should use `NonKeywordIdentifier`.

* **Given** the string `"Result<URL, Error>?"`, **when** parsed by
  `UrkelTypeExpr`, **then** it succeeds returning `"Result<URL, Error>?"` and
  consumes the input up to a `")"`, `","`, or newline.

* **Given** a line `"## Monitors a Bluetooth peripheral"`, **when** parsed by
  `DocCommentLineParser`, **then** it returns `DocComment(text: "Monitors a Bluetooth peripheral")`.

* **Given** a line `"# this is a plain comment"`, **when** parsed by
  `TriviaLine`, **then** it succeeds and produces no `DocComment` (plain
  comments are discarded).

* **Given** a mix of blank lines, comment lines, and doc-comment lines,
  **when** parsed by `TriviaLines` (zero-or-more trivia), **then** only
  `DocComment` values are returned in a `[DocComment]` array.

## Implementation Details

* Add to `Package.swift`:
  ```swift
  .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.14.0")
  ```
  Add `"Parsing"` to the `Urkel` target dependencies.
* Create `Sources/Urkel/Parser/Primitives/`:
  - `InlineWhitespace.swift` — parses one-or-more space/tab characters (not newlines).
  - `UrkelNewline.swift` — parses `\n` or `\r\n`.
  - `UrkelIdentifier.swift` — parses a valid identifier per the grammar.
  - `NonKeywordIdentifier.swift` — wraps `UrkelIdentifier` and fails if the
    result is a reserved keyword.
  - `UrkelTypeExpr.swift` — reads characters until `)`, `,`, or newline.
  - `TriviaLine.swift` — `BlankLine`, `CommentLine`, `DocCommentLine`, `TriviaLine` combinator.
  - `Keywords.swift` — `static let all: Set<String>` and `KeywordCheck` helper.
* All parsers are internal types (not `public`) — the public API surface is
  defined at the `UrkelParser` level in US-2.4.
* Each parser file has a corresponding `// EBNF: RuleName ::= …` comment at the
  top linking it to the grammar.

## Testing Strategy

* Create `Tests/UrkelTests/ParserTests/PrimitivesTests.swift`.
* Test each primitive in isolation with both valid and invalid inputs:
  - `UrkelIdentifier` — valid: `"_foo"`, `"State1"`; invalid: `"1state"`, `"@bad"`.
  - `NonKeywordIdentifier` — fails on every string in `Keywords.all`.
  - `UrkelTypeExpr` — captures `"[String: Any]?"`, stops at `,` and `)`.
  - `DocCommentLineParser` — strips `"## "` prefix; preserves trailing spaces in text.
  - `TriviaLines` — mixed trivia; asserts only doc comments are surfaced.
* All tests use `swift-testing` (`#expect`, `#require`).

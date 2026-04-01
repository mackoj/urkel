# US-2.5: Bidirectional Printing (AST → .urkel)

## Objective

Make every `swift-parsing` combinator bidirectional by conforming it to
`ParserPrinter`, then expose `UrkelPrinter.print(_ file: UrkelFile) -> String`
as the canonical way to serialise an AST back to a formatted `.urkel` source
string. This gives Urkel a zero-effort auto-formatter and enables the
roundtrip property: `parse(print(ast)) == ast`.

## Background

`swift-parsing` combinators that conform to `ParserPrinter` can run in both
directions without duplicating any formatting logic. The printer is the inverse
of the parser: given an AST node it emits the canonical text that the parser
would have accepted. This is a unique feature of the library and a core reason
it was chosen over hand-written parsing.

Bidirectional printing unlocks three concrete use-cases:

1. **Auto-formatter** — a `urkel format` CLI command (or VS Code save hook) can
   normalise any hand-written `.urkel` file to a canonical style.
2. **Code generation of `.urkel`** — tools can construct an AST programmatically
   (e.g. a scaffold wizard) and emit valid source without string templates.
3. **Roundtrip testing** — `parse(print(ast)) == ast` is a law that can be
   property-tested with arbitrary ASTs, catching regressions in both directions.

## Canonical Formatting Rules

These rules define the output of the printer — they are the "golden format" that
`urkel format` enforces:

| Construct | Rule |
|-----------|------|
| Indentation | 2 spaces per level |
| `@states` header | no indent, one blank line before |
| `@transitions` header | no indent, one blank line before |
| `@entry` / `@exit` | no indent |
| `@import` / `@parallel` | no indent |
| Simple state | 2-space indent |
| Compound state body | 4-space indent for children; closing `}` at 2 spaces |
| Transition | 2-space indent; arrows aligned to column 40 (best-effort) |
| `@on` reactive | 2-space indent |
| Parameters | single space after `:`, no space before `,` |
| Action list | single space after `/`, comma-space between actions |
| Doc comments | `## ` prefix, immediately before the declaration they annotate |
| Plain comments | stripped (not printed) |
| Trailing newline | exactly one at end of file |

## Acceptance Criteria

* **Given** a `UrkelFile` AST with a machine name, two imports, and a flat
  `@states`/`@transitions` section, **when** `UrkelPrinter.print(_:)` is called,
  **then** the output parses back to an equal AST: `parse(print(ast)) == ast`.

* **Given** a `.urkel` file with inconsistent indentation (tabs, extra spaces),
  **when** parsed and then printed, **then** the output conforms to the canonical
  formatting rules above.

* **Given** a hand-built AST containing a compound state, parallel regions, an
  `@on` reactive statement, and a fork clause, **when** printed, **then** the
  output is a valid `.urkel` string that parses back to the original AST.

* **Given** a `DocComment` attached to a `SimpleStateDecl`, **when** printed,
  **then** the `## text` line appears immediately before the state declaration.

* **Given** a file whose plain `#` comments are parsed away, **when** printed,
  **then** the output contains no `#` comment lines — plain comments are
  intentionally stripped by the formatter.

* **Given** an AST constructed programmatically (no source text, all `range == nil`),
  **when** printed, **then** the output is a fully valid `.urkel` file.

* **Given** `urkel format <file>` is run on any example file, **when** the
  command completes, **then** the file content equals `UrkelPrinter.print(parse(file))`.

## Implementation Details

* Conform all parsers from US-2.1–3.4 to `ParserPrinter` by implementing a
  `print(_ output:, into input: inout String) throws` method on each.
* Create `Sources/Urkel/Printer/UrkelPrinter.swift`:
  ```swift
  public struct UrkelPrinter {
    public static func print(_ file: UrkelFile) -> String
  }
  ```
* Create `Sources/Urkel/Printer/PrintContext.swift` — carries current
  indentation depth, column tracker for arrow alignment, and a doc-comment
  buffer. Passed through the printer recursively.
* Arrow alignment: collect all transition lines in a block, compute the
  longest source+event prefix, then pad each line to that column (capped at 40).
* Add `urkel format [--check] <file>` subcommand to the CLI:
  - Without `--check`: overwrites the file with canonical output.
  - With `--check`: exits non-zero if the file is not already canonical (useful
    in CI).

## Testing Strategy

* Create `Tests/UrkelTests/PrinterTests/UrkelPrinterTests.swift`.
* **Roundtrip law** — for each example `.urkel` file:
  1. Parse → `ast1`.
  2. Print → `text`.
  3. Parse `text` → `ast2`.
  4. Assert `ast1 == ast2`.
* **Idempotency law** — `print(parse(print(ast)))` equals `print(ast)` (printing
  is stable under repeated application).
* **Formatting tests** — parse a deliberately messy `.urkel` string; assert the
  printed output matches a golden snapshot (use `swift-snapshot-testing` or
  inline string comparison).
* **Programmatic construction** — build a `UrkelFile` AST by hand with no source
  ranges; call `print`; assert the output parses without errors.
* **`urkel format --check`** — integration test: create a temp file that differs
  from canonical; assert exit code is non-zero.

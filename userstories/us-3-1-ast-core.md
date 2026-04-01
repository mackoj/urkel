# US-3.1: Core AST Model

## Objective

Define the foundational Swift data types that represent a parsed `.urkel` file in
memory. These types become the single source of truth for the entire compilation
pipeline: parser → validator → emitter → visualiser. Every subsequent epic
depends on this model being complete, typed, and testable.

## Background

The v2 grammar (`grammar.ebnf`) is significantly richer than v1. A minimal AST
covering only the flat-machine constructs leaves compound states, parallel
regions, doc-comment attachment, and advanced modifiers unrepresented. This
story covers the **core spine** of the model — the nodes required by every
machine, however simple. US-3.2 extends it with the advanced node types.

The model must satisfy three hard constraints:

1. **Structural completeness** — every syntactic construct in `grammar.ebnf`
   maps to at least one typed Swift node; nothing is represented as a raw `String`
   except BYOT type expressions (by design).
2. **Equatable throughout** — every node conforms to `Equatable` so parser
   unit tests can write `#expect(parsed == expected)` without custom comparators.
3. **Forward-compatible** — nodes use `enum` for variant types and optional
   properties for optional grammar productions, making it safe to add fields in
   US-3.2 without breaking existing callers.

## AST Nodes (this story)

```
UrkelFile
  machineName: String
  contextType: String?          # "machine Name: ContextType"
  docComments: [DocComment]     # ## comments attached to the machine decl
  imports: [ImportDecl]
  parallels: [ParallelDecl]     # placeholder — detailed in US-3.2
  states: [StateDecl]           # placeholder — detailed in US-3.2
  entryExitHooks: [EntryExitDecl]
  transitions: [TransitionDecl] # placeholder — detailed in US-3.2

ImportDecl
  name: String                  # @import Name
  from: String?                 # optional "from Package"
  docComments: [DocComment]

Parameter
  label: String                 # "device" in "device: Peripheral"
  typeExpr: String              # raw BYOT string — never interpreted

DocComment
  text: String                  # content of a "## ..." line (stripped of "## ")
```

`StateDecl`, `TransitionDecl`, and `ParallelDecl` are declared in this story as
opaque placeholder types (empty structs) so that `UrkelFile` compiles. They are
fully fleshed out in US-3.2.

## Acceptance Criteria

* **Given** a `UrkelFile` constructed with a machine name, optional context type,
  two imports, and an empty states/transitions list, **when** compared to an
  identically constructed instance, **then** `==` returns `true`.

* **Given** `ImportDecl(name: "Scanner", from: "ScannerKit")` and
  `ImportDecl(name: "Scanner", from: nil)`, **when** compared, **then** `==`
  returns `false`.

* **Given** a `Parameter` with `label: "url"` and `typeExpr: "[String: Any]?"`,
  **when** the `typeExpr` is read, **then** it equals `"[String: Any]?"` exactly —
  no trimming, normalisation, or type parsing performed.

* **Given** all node types in this story, **when** compiled, **then** every type
  conforms to `Equatable` and `Sendable`. `Codable` conformance is derived where
  possible (BYOT `String` fields are always codable).

* **Given** a `DocComment` attached to an `ImportDecl`, **when** the import is
  printed back (US-2.5), **then** the doc comment precedes the `@import` line.

## Implementation Details

* Create `Sources/Urkel/AST/UrkelFile.swift` — the root node and `ImportDecl`.
* Create `Sources/Urkel/AST/Parameter.swift` — shared across states, events,
  timers, and forks.
* Create `Sources/Urkel/AST/DocComment.swift`.
* Create `Sources/Urkel/AST/Placeholders.swift` — stub `StateDecl`,
  `TransitionDecl`, `ParallelDecl` (replaced in US-3.2).
* All types are `public struct … : Equatable, Sendable`.
* Derive `Codable` on all types that do not hold non-codable fields (all do in
  this story — `String`, `[String]`, and optionals of those are always codable).
* No dependencies outside the Swift standard library.

## Testing Strategy

* Create `Tests/UrkelTests/ASTTests/UrkelFileTests.swift`.
* Construct a `UrkelFile` representing the `FolderWatch` machine (name only,
  one import, no context type). Assert equality with a second identical instance.
* Construct two `ImportDecl` values differing only in `from`; assert `!=`.
* Construct a `Parameter` with a complex BYOT type (`Result<URL, Error>?`);
  assert the raw string is preserved exactly.
* Run the full test suite with `xcrun swift test --skip generatedSwiftCompiles`.

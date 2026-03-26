# US-12.1: Replace String-Concatenation Emitter with SwiftSyntaxBuilder

**Epic:** 12 — Emitter Architecture  
**Depends on:** US-4.x (existing emitter), US-11.4 (actor bridge — the most complex generated shape today)  
**Status:** Proposed  
**Package reference:** `apple/swift-syntax` (`SwiftSyntaxBuilder` target)

---

## 1. Objective

Rewrite `SwiftCodeEmitter` to construct a typed Swift syntax tree using
`SwiftSyntaxBuilder` instead of building strings through interpolation and manual
`joined(separator:)` joins. The output is obtained by calling the library's
pretty-printer on the finished tree — indentation, spacing, and punctuation are
produced automatically and are always valid Swift.

---

## 2. Why This Matters — The Case Against String Concatenation

### 2.1 Silent failures surface far from their cause

When string-built code has a structural defect — a missing comma between init
arguments, a stray `in` inside a zero-argument closure, unbalanced braces — the
only signal is a compiler error on the *generated* file.  That error message names
a line in the generated Swift, not the line in `SwiftCodeEmitter.swift` that
produced it.  The user sees a cryptic error in a file they did not write and cannot
easily fix.

With `SwiftSyntaxBuilder` every node constructor is a typed call that fails at
the emitter's own build time (or at least at the Swift level, not in generated
output).  Structural invariants — "an `init` body is a `CodeBlockSyntax`
containing `StatementSyntax` nodes" — are enforced by the Swift type system.

### 2.2 Indentation is an invisible, error-prone responsibility

`SwiftCodeEmitter.swift` today contains hundreds of manually counted space
literals: `"            "`, `",\n        "`, `"    \(propsSection)"`.  Every new
indentation level added by a feature — the US-11.4 actor, the `fromRuntime`
wrapped closures, the `takePhase` body — required the author to count spaces by
hand, verify them visually, and adjust every affected string literal.

`SwiftSyntaxBuilder`'s `BasicFormat` / `SwiftSyntax.CodeGenerationFormat`
pretty-printer computes indentation from the tree structure.  The emitter author
writes `FunctionDeclSyntax { ... }` and the printer decides where the braces and
their contents go.

### 2.3 Composition is unsafe with strings, natural with syntax nodes

Today, assembling a generated function involves:

```swift
let parts = [header, closureAliases, composedAliasSection, ...]
    .filter { !$0.isEmpty }
    .joined(separator: "\n")
```

Each `part` is an opaque `String`.  Nothing prevents accidentally double-joining a
section, emitting it in the wrong order, or including it under the wrong
surrounding declaration.

With syntax nodes each helper returns a `DeclSyntax` or `MemberBlockItemSyntax`.
They compose through typed lists (`MemberBlockItemListSyntax`,
`CodeBlockItemListSyntax`).  Putting a statement where a declaration is required
is a compile-time type error, not a runtime formatting surprise.

### 2.4 The existing emitter has already exceeded its complexity budget

`SwiftCodeEmitter.swift` reached 800 lines before US-11.4.  US-11.4 pushed it
past 1200 lines.  US-11.4's `emitSubFSMActors` and the composed-machine branch of
`emitClientRuntimeBuilder` are the most complex functions in the codebase: nested
string interpolations inside closures inside interpolations, with separate
indentation decisions for every nesting level.

The root cause is not that US-11.4 is intrinsically complex — the actor bridge
is conceptually simple.  The complexity comes from the impedance mismatch between
*describing* code structure (what the emitter wants to do) and *encoding* code as
characters (what string interpolation forces it to do).

### 2.5 `swift-format` or `SwiftLint` cannot fix structural errors post-hoc

A common counter-argument is "just run a formatter on the output."  Formatters fix
*style* (indentation, spacing) but cannot fix *structural* errors (mismatched
parentheses, wrong argument labels).  `SwiftSyntaxBuilder` prevents structural
errors at construction time.  A formatter running afterward still produces
correctly formatted output, but it is not a substitute for correctness during
construction.

### 2.6 Diffing generated files becomes meaningful

The current emitter emits whatever indentation its `joined(separator:)` chains
produce.  When a feature changes the depth of a nested construct, every inner line
of that construct changes its leading spaces, bloating `git diff` with noise.

`SwiftSyntaxBuilder`'s printer produces canonical output: the same tree always
produces the same text, indented by a deterministic algorithm.  `git diff` on
generated files shows only semantically meaningful changes.

---

## 3. Current Pain Points (Concrete Examples)

| Location | Problem |
|---|---|
| `emitClientRuntimeBuilder` — `fromRuntime` composed branch | Three levels of string interpolation building `{ ctx in \n...\n return ... }` closures; indentation counted by hand per nesting level |
| `emitSubFSMActors` | Multiline actor body assembled via `"""..."""` with `\(stopMethodCore)` and `\(errorMethodCore)` injected mid-literal; tab/space mix is invisible |
| `emitStateMachineFile` | `propsSection`, `allInitParams`, `allAssignments` joined with `",\n"` or `"\n"` depending on whether they are non-empty; empty-string guards everywhere |
| `placeholderFactoryClosure` | Counts `_` characters to generate `_ in` vs `_, _ in`; breaks silently if count is wrong |
| Every function | `filter { !$0.isEmpty }.joined(separator: "\n\n")` is the universal combinator — semantics (what goes where) are expressed solely through ordering and filtering |

---

## 4. Proposed Approach

### 4.1 Add `swift-syntax` as a dependency

```swift
// Package.swift
.package(url: "https://github.com/apple/swift-syntax.git", from: "603.0.0<605.0.0"),
```

Add `SwiftSyntax` and `SwiftSyntaxBuilder` to the `Urkel` library target.

### 4.2 Introduce `SwiftSyntaxEmitter` alongside the existing emitter

Do **not** delete `SwiftCodeEmitter` in one PR.  Instead:

1. Create `Sources/Urkel/SwiftSyntaxEmitter.swift` that satisfies the same
   `EmittedFiles` contract as `SwiftCodeEmitter`.
2. Migrate one emitter function at a time, verified by the existing snapshot
   tests (the output text must be equivalent or canonically reformatted).
3. Once all functions are migrated and tests pass, remove `SwiftCodeEmitter`.

### 4.3 Structure of `SwiftSyntaxEmitter`

Each conceptual section of the generated file becomes a function that returns a
typed syntax node:

```swift
// State machine file
func stateMarkerDecls(for ast: MachineAST, names: Names) -> [DeclSyntax]
func runtimeContextDecl(for ast: MachineAST, names: Names) -> StructDeclSyntax?
func machineStructDecl(for ast: MachineAST, names: Names) -> StructDeclSyntax
func transitionExtensionDecls(for ast: MachineAST, names: Names) -> [ExtensionDeclSyntax]
func combinedStateEnumDecl(for ast: MachineAST, names: Names) -> EnumDeclSyntax

// Client file
func subFSMActorDecls(for ast: MachineAST, composedASTs: [String: MachineAST], names: Names) -> [ActorDeclSyntax]
func clientRuntimeStructDecl(for ast: MachineAST, composedASTs: [String: MachineAST], names: Names) -> StructDeclSyntax
func fromRuntimeExtensionDecl(for ast: MachineAST, composedASTs: [String: MachineAST], names: Names) -> ExtensionDeclSyntax
func clientStructDecl(for ast: MachineAST, names: Names) -> StructDeclSyntax

// Dependency file
func dependencyExtensionDecl(for ast: MachineAST, names: Names) -> ExtensionDeclSyntax
func dependencyValuesExtensionDecl(for ast: MachineAST, names: Names) -> ExtensionDeclSyntax
```

The top-level `emit()` calls these, assembles a `SourceFileSyntax`, and calls
`BasicFormat().reformat(syntax:)` to get the final `String`.

### 4.4 Transition the complex cases first

Priority order:

1. `emitSubFSMActors` — most complex, greatest immediate benefit
2. `emitClientRuntimeBuilder` (composed branch) — deeply nested closures
3. `emitStateMachineFile` — most lines saved from empty-string guards
4. `emitExtensions` — straightforward, many repeated patterns
5. Remaining helpers

### 4.5 Preserve output contract

The `EmittedFiles` struct and the `emit(ast:composedASTs:swiftImportsOverride:nonescapable:)`
signature remain unchanged.  All callers (CLI, plugin, watch service) are
unaffected.  The only observable change is that the generated text may be
reformatted to `BasicFormat` canonical style (4-space indentation, consistent
brace placement).  Existing snapshot tests should be updated to the new canonical
form.

---

## 5. Acceptance Criteria

### 5.1 No string interpolation for structural Swift tokens

- **Given** the new emitter is complete.
- **When** a code reviewer reads `SwiftSyntaxEmitter.swift`.
- **Then** there are no `"""..."""` multi-line string literals that encode Swift
  syntax with manually embedded newlines and spaces.
- **And** there are no `.joined(separator: ",\n        ")` calls that encode
  indentation as a separator.

### 5.2 Structural errors are caught at emitter compile time

- **Given** a developer makes a change that would put a `StmtSyntax` where a
  `DeclSyntax` is required (e.g., accidentally nesting a transition method inside
  a `CodeBlockSyntax` instead of a `MemberBlockSyntax`).
- **When** they build the Urkel library.
- **Then** the Swift compiler reports a type error in `SwiftSyntaxEmitter.swift`
  — not a parse error in a generated `.swift` file at test time.

### 5.3 All 71 existing tests pass unchanged (modulo canonical formatting)

- **Given** the emitter is fully migrated.
- **When** `xcrun swift test --skip "generatedSwiftCompiles"` is run.
- **Then** all 71 tests pass (or the tests are updated to the new canonical format
  and then pass).

### 5.4 `generatedSwiftCompiles` integration test passes

- **Given** the emitter is fully migrated.
- **When** `xcrun swift test` is run (including the compilation fixture test).
- **Then** generated files for all fixture machines compile without errors.

### 5.5 `emitSubFSMActors` is the most legible gain

- **Given** the US-11.4 `@compose` actor bridge.
- **When** a developer reads `SwiftSyntaxEmitter.emitSubFSMActors`.
- **Then** they can understand the generated actor structure directly from the
  Swift syntax builder calls — the builder reads like a description of the code
  being produced, not like a template with escape characters.

### 5.6 `SwiftCodeEmitter.swift` is deleted

- **Given** all functions have been migrated and all tests pass.
- **Then** `SwiftCodeEmitter.swift` is removed from the repository.
- **And** `SwiftSyntaxEmitter` is renamed to `SwiftCodeEmitter` (or the public
  type alias `SwiftCodeEmitter = SwiftSyntaxEmitter` is provided for any callers
  using it by name).

---

## 6. Implementation Details

### 6.1 Dependency version

Pin to the same major version as the Swift toolchain used by the package
(`swift-syntax` version mirrors the Swift toolchain: Swift 6.1 → 600.x).
Use `.upToNextMinor` to avoid unexpected source breaks.

### 6.2 `BasicFormat` vs `SwiftSyntax.CodeGenerationFormat`

`BasicFormat` (built into `swift-syntax`) produces human-readable,
`swift-format`-compatible output.  It is the right default for generated source
files that will be checked in and read by developers.

### 6.3 Trivia (comments, blank lines)

MARK comments (`// MARK: - Xxx`) and doc comments (`/// ...`) are represented as
leading trivia on their associated declaration node, not as separate string
injections.  Use `DeclSyntax.with(\.leadingTrivia, .docComment(...))`.

### 6.4 The `~Copyable` / `~Escapable` suppressions

`SwiftSyntaxBuilder` represents these as `InheritedTypeSyntax` with a `~` prefix.
Verify the API supports suppression syntax before committing to this approach;
fall back to a raw token list if needed.

### 6.5 Incremental migration with a feature flag

During migration, a `useSwiftSyntaxEmitter: Bool` parameter (defaulting to
`false`) can be added to `emit()`.  Flip the default to `true` once all tests
pass.  Remove the flag and the old emitter together.

---

## 7. Testing Strategy

- Existing `UrkelEmitterTests` use `#expect(output.contains("..."))` assertions.
  These remain valid during migration (modulo whitespace); update the expected
  substrings to match `BasicFormat`'s canonical style.
- Add one new test that calls the new emitter on every fixture AST and asserts
  the output parses as valid Swift (using `SwiftParser.parse(source:)` and
  checking `Diagnostics` is empty).
- The `generatedSwiftCompiles` integration test remains the ultimate
  correctness gate.

---

## 8. Out of Scope

- Kotlin / Mustache emitters — they do not produce Swift and are unaffected.
- The parser (`UrkelParser`) — only the emitter is refactored.
- The `EmittedFiles` public API — it stays unchanged.
- Style changes to existing generated code beyond what `BasicFormat` normalises.

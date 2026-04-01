# US-3.3: Source Range Tracking

## Objective

Attach precise source location metadata (`SourceRange`) to every AST node so
that the validator can emit line/column-accurate diagnostics and the Language
Server (Epic 6) can draw error squiggles, semantic highlights, and support
click-to-definition — all without a separate pass over the raw text.

## Background

Without source ranges the pipeline works, but errors surface as name-only
strings: `"Undefined state 'Runing'"`. With ranges they become IDE-quality
diagnostics: `"error: undefined state 'Runing' [folderwatch.urkel:14:28]"`.
The `swift-parsing` library tracks `Substring` positions naturally; this story
designs the range type that those positions will be mapped into in Epic 3.

Crucially, **equality of AST nodes must ignore source ranges**. Two structurally
identical machines parsed from differently indented files must compare as equal.
This keeps parser tests simple (compare against hand-built ASTs that have no
ranges) while letting the IDE consume rich location data at runtime.

## Types Introduced

```swift
public struct SourceLocation: Sendable, Codable {
  public var line: Int       // 1-based
  public var column: Int     // 1-based
  public var offset: Int     // 0-based UTF-8 byte offset from file start
}

public struct SourceRange: Sendable, Codable {
  public var start: SourceLocation
  public var end: SourceLocation   // exclusive end (points just past last char)
}
```

Every AST node gains an optional range property:

```swift
// example
public struct SimpleStateDecl: Equatable, Sendable, Codable {
  public var kind: StateKind
  public var params: [Parameter]
  public var name: String
  public var history: HistoryModifier?
  public var docComments: [DocComment]
  public var range: SourceRange?    // ← new
}
```

## Acceptance Criteria

* **Given** two `SimpleStateDecl` instances that are structurally identical but
  have different (or nil vs non-nil) `range` values, **when** compared with `==`,
  **then** the result is `true` — range is excluded from `Equatable`.

* **Given** a `SourceRange` where `start.line == 3`, `start.column == 5`, and
  `end.line == 3`, `end.column == 14`, **when** encoded to JSON and decoded,
  **then** the round-trip preserves all fields exactly (`Codable` works).

* **Given** all AST node types from US-3.1 and US-3.2, **when** each gains
  `var range: SourceRange?`, **then** the package still compiles and all
  existing equality tests still pass without modification.

* **Given** a `SourceLocation` at `offset: 0`, **when** considered the start
  of a file, **then** `line == 1` and `column == 1`.

* **Given** the `UrkelFile` root node gains a `range` spanning the entire file,
  **when** its `range.start` is inspected, **then** `line == 1`, `column == 1`.

## Implementation Details

* Create `Sources/Urkel/AST/SourceRange.swift`:
  - `SourceLocation` and `SourceRange` as `public struct`.
  - Both conform to `Equatable`, `Hashable`, `Sendable`, `Codable`, `CustomStringConvertible`
    (e.g. `"3:5–3:14"`).
* Update every AST node from US-3.1 and US-3.2 to add `public var range: SourceRange?`.
* Implement `Equatable` manually (or via a `@EquatableIgnoring` wrapper pattern) on
  every node so that `range` is excluded from the comparison. A clean approach:
  - Add a static `func == (lhs:rhs:)` that compares all fields **except** `range`.
  - Document this contract with a `// range excluded from Equatable` comment next
    to each implementation.
* `Codable` synthesis includes `range` (useful for serialising ASTs to disk for
  caching or incremental builds).
* `Hashable` synthesis also excludes `range` (consistent with `Equatable`).

## Testing Strategy

* Add `SourceRangeTests.swift`:
  - `SourceRange` encodes to expected JSON; decode round-trip.
  - `CustomStringConvertible` produces `"1:1–1:10"` for a single-line range.
* Add range-inequality tests to each existing AST test file:
  - Construct node A with `range = nil`; construct identical node B with a
    non-nil `range`. Assert `A == B`.
  - Change a structural field (e.g. state name); assert `A != B` even if ranges match.
* Verify that the `BluetoothBlender` reference fixture from US-3.2 still passes
  after the range property is added.

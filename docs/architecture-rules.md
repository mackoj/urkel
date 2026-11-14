# Architecture rules

The mechanical part of `CODING_STANDARDS.md`, enforced by the `Architecture/` package with [swift-llm-check](https://github.com/mackoj/swift-llm-check): `swift test --package-path Architecture` (macOS). Generated from its rules; do not edit by hand.

## layering

Which module may import what. Read before you add an `import` to `Sources`.

### Each library module imports only Foundation and the dependencies `Package.swift` gives it.

`modules-import-within-their-budget`: Urkel is split into fine-grained products so a client imports only what it needs (CODING_STANDARDS.md, "Module layering"): `UrkelAST` has no dependencies, the parser adds swift-parsing, the Swift emitter adds swift-syntax, the Mustache emitter adds swift-mustache, and validation and visualisation need only the AST. An extra import couples two layers, or makes every client of a small product build a large one.

**How to fix:** Move the code to the module that already owns the dependency, or pass the value in from the umbrella `Urkel` module, which orchestrates the pipeline. A new dependency is a decision for the maintainer, recorded in `Package.swift` and in `Detect.importBudget` first.

Bad:

```swift
// Sources/UrkelValidation/UrkelValidator.swift
import UrkelParser
```

Good:

```swift
// Sources/UrkelValidation/UrkelValidator.swift
import UrkelAST
public static func validate(_ file: UrkelFile) -> [Diagnostic]  // the caller parses
```

## purity

The compiler pipeline is pure. Read before you reach for the file system, a clock or `print`.

### The AST, parser, validator, Swift emitter and visualiser perform no I/O and read no clock.

`pipeline-performs-no-io`: The pipeline is a function from `.urkel` text to an AST, diagnostics and Swift source (CODING_STANDARDS.md, "Pure pipeline"). The same input gives the same output in the build plugin, the CLI, the language server and the tests. Reading files, spawning processes, `Date()` or `print` belong to the umbrella `Urkel` module and the CLI, which own configuration and output paths.

**How to fix:** Take the text or value as a parameter and return the result; report problems as a thrown error or a `Diagnostic`, never by printing. File handling goes in `UrkelGenerator` or `UrkelCLI`.

Bad:

```swift
public func emit(path: String) throws -> EmittedFiles {
    let source = try String(contentsOfFile: path)  // and FileManager.default…
```

Good:

```swift
public func emit(file: UrkelFile) throws -> EmittedFiles
```

## errors

How the library reports failure. Read before you add a `try!` or a trap.

### Library code has no `try!`, `as!`, `fatalError`, `precondition` or `preconditionFailure`.

`library-never-traps`: Urkel runs inside a client's build (the SPM plugin), their editor (the language server) and their tests. A trap there crashes the host process instead of pointing at the line of `.urkel` that caused it (CODING_STANDARDS.md, "Errors are values"). The emitter may write `fatalError` into generated code as text; that is a string, not a call, and passes.

**How to fix:** Throw `UrkelParseError` with a line number, return a `Diagnostic`, or throw `SwiftSyntaxEmitterError`. Use `try`/`as?` and handle the failure.

Bad:

```swift
let duration = try! DurationParser().parse(&input)
```

Good:

```swift
guard let duration = try? DurationParser().parse(&input) else {
    throw UrkelParseError(message: "Expected a duration", line: lineNum)
}
```

## models

The AST is plain data. Read before you add or change a type in `Sources/UrkelAST`.

### Every public type in `UrkelAST` is a struct or enum declared `Equatable`, `Sendable` and `Codable`.

`ast-types-are-values`: The AST is the single source of truth shared by the parser, validator, emitters, visualiser and language server (CODING_STANDARDS.md, "The AST is plain data"). `Equatable` lets the parser's round-trip and property tests compare whole trees, `Sendable` lets the language server and the watch service hand it across tasks, and `Codable` feeds the visualiser and template contexts. A class would share mutable state between those consumers.

**How to fix:** Make it a struct or enum and declare all three conformances on the type, like its neighbours.

Bad:

```swift
public struct GuardDecl: Equatable {
```

Good:

```swift
public struct GuardDecl: Equatable, Sendable, Codable {
```

## testing

Swift Testing, and no silenced tests. Read before you add, skip or mark a test.

### Tests use Swift Testing, never XCTest.

`tests-use-swift-testing`: The suite is Swift Testing only (CODING_STANDARDS.md, "Tests"): `@Test`, `#expect` and `#require` give one failure style, parameterised tests over the example machines, and parallel runs.

**How to fix:** Write an `@Suite` of `@Test` functions with `#expect` and `#require`, and `import Testing`.

Bad:

```swift
import XCTest
final class ParserTests: XCTestCase { func testStates() { XCTAssertEqual(…) } }
```

Good:

```swift
import Testing
@Suite struct ParserTests { @Test func states() { #expect(…) } }
```

### `withKnownIssue` says what the issue is and where it is tracked.

`known-issues-explain-themselves`: A known issue hides a failing expectation. Without a reason, the next reader cannot tell a bug waiting for a fix from a test nobody understood, and nobody removes it once the bug is fixed.

**How to fix:** Pass the reason as the first argument, with the GitHub issue or user story that tracks it.

Bad:

```swift
withKnownIssue { try emitter.emit(file: parallelMachine) }
```

Good:

```swift
withKnownIssue("Parallel regions are not emitted yet (US-1.12)") {
    try emitter.emit(file: parallelMachine)
}
```

### No test or suite is `.disabled`.

`tests-are-not-disabled`: A disabled test still reads as coverage while checking nothing. A failing behaviour is either fixed, or asserted as a known issue that names what tracks it.

**How to fix:** Fix the code or the test. If the bug must wait, wrap the failing part in `withKnownIssue("…")`.

Bad:

```swift
@Test(.disabled("flaky")) func watchRegenerates() throws {
```

Good:

```swift
@Test func watchRegenerates() throws {
```

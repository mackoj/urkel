import LLMCheck

extension Rule {
    static let modulesImportWithinTheirBudget = Rule(
        id: "modules-import-within-their-budget",
        title: "Each library module imports only Foundation and the dependencies `Package.swift` gives it.",
        category: .layering,
        rationale: """
            Urkel is split into fine-grained products so a client imports only what it needs (CODING_STANDARDS.md, \
            "Module layering"): `UrkelAST` has no dependencies, the parser adds swift-parsing, the Swift emitter adds \
            swift-syntax, the Mustache emitter adds swift-mustache, and validation and visualisation need only the \
            AST. An extra import couples two layers, or makes every client of a small product build a large one.
            """,
        howToFix: """
            Move the code to the module that already owns the dependency, or pass the value in from the umbrella \
            `Urkel` module, which orchestrates the pipeline. A new dependency is a decision for the maintainer, \
            recorded in `Package.swift` and in `Detect.importBudget` first.
            """,
        badExample: """
            // Sources/UrkelValidation/UrkelValidator.swift
            import UrkelParser
            """,
        goodExample: """
            // Sources/UrkelValidation/UrkelValidator.swift
            import UrkelAST
            public static func validate(_ file: UrkelFile) -> [Diagnostic]  // the caller parses
            """
    )

    static let pipelinePerformsNoIO = Rule(
        id: "pipeline-performs-no-io",
        title: "The AST, parser, validator, Swift emitter and visualiser perform no I/O and read no clock.",
        category: .purity,
        rationale: """
            The pipeline is a function from `.urkel` text to an AST, diagnostics and Swift source \
            (CODING_STANDARDS.md, "Pure pipeline"). The same input gives the same output in the build plugin, the \
            CLI, the language server and the tests. Reading files, spawning processes, `Date()` or `print` belong to \
            the umbrella `Urkel` module and the CLI, which own configuration and output paths.
            """,
        howToFix: """
            Take the text or value as a parameter and return the result; report problems as a thrown error or a \
            `Diagnostic`, never by printing. File handling goes in `UrkelGenerator` or `UrkelCLI`.
            """,
        badExample: """
            public func emit(path: String) throws -> EmittedFiles {
                let source = try String(contentsOfFile: path)  // and FileManager.default…
            """,
        goodExample: """
            public func emit(file: UrkelFile) throws -> EmittedFiles
            """
    )

    static let libraryNeverTraps = Rule(
        id: "library-never-traps",
        title: "Library code has no `try!`, `as!`, `fatalError`, `precondition` or `preconditionFailure`.",
        category: .errors,
        rationale: """
            Urkel runs inside a client's build (the SPM plugin), their editor (the language server) and their tests. \
            A trap there crashes the host process instead of pointing at the line of `.urkel` that caused it \
            (CODING_STANDARDS.md, "Errors are values"). The emitter may write `fatalError` into generated code as \
            text; that is a string, not a call, and passes.
            """,
        howToFix: """
            Throw `UrkelParseError` with a line number, return a `Diagnostic`, or throw \
            `SwiftSyntaxEmitterError`. Use `try`/`as?` and handle the failure.
            """,
        badExample: """
            let duration = try! DurationParser().parse(&input)
            """,
        goodExample: """
            guard let duration = try? DurationParser().parse(&input) else {
                throw UrkelParseError(message: "Expected a duration", line: lineNum)
            }
            """
    )

    static let astTypesAreValues = Rule(
        id: "ast-types-are-values",
        title: "Every public type in `UrkelAST` is a struct or enum declared `Equatable`, `Sendable` and `Codable`.",
        category: .models,
        rationale: """
            The AST is the single source of truth shared by the parser, validator, emitters, visualiser and \
            language server (CODING_STANDARDS.md, "The AST is plain data"). `Equatable` lets the parser's \
            round-trip and property tests compare whole trees, `Sendable` lets the language server and the watch \
            service hand it across tasks, and `Codable` feeds the visualiser and template contexts. A class would \
            share mutable state between those consumers.
            """,
        howToFix: "Make it a struct or enum and declare all three conformances on the type, like its neighbours.",
        badExample: "public struct GuardDecl: Equatable {",
        goodExample: "public struct GuardDecl: Equatable, Sendable, Codable {"
    )

    static let testsUseSwiftTesting = Rule(
        id: "tests-use-swift-testing",
        title: "Tests use Swift Testing, never XCTest.",
        category: .testing,
        rationale: """
            The suite is Swift Testing only (CODING_STANDARDS.md, "Tests"): `@Test`, `#expect` and `#require` give \
            one failure style, parameterised tests over the example machines, and parallel runs.
            """,
        howToFix: "Write an `@Suite` of `@Test` functions with `#expect` and `#require`, and `import Testing`.",
        badExample: """
            import XCTest
            final class ParserTests: XCTestCase { func testStates() { XCTAssertEqual(…) } }
            """,
        goodExample: """
            import Testing
            @Suite struct ParserTests { @Test func states() { #expect(…) } }
            """
    )

    static let knownIssuesExplainThemselves = Rule(
        id: "known-issues-explain-themselves",
        title: "`withKnownIssue` says what the issue is and where it is tracked.",
        category: .testing,
        rationale: """
            A known issue hides a failing expectation. Without a reason, the next reader cannot tell a bug waiting \
            for a fix from a test nobody understood, and nobody removes it once the bug is fixed.
            """,
        howToFix: "Pass the reason as the first argument, with the GitHub issue or user story that tracks it.",
        badExample: "withKnownIssue { try emitter.emit(file: parallelMachine) }",
        goodExample: """
            withKnownIssue("Parallel regions are not emitted yet (US-1.12)") {
                try emitter.emit(file: parallelMachine)
            }
            """
    )

    static let testsAreNotDisabled = Rule(
        id: "tests-are-not-disabled",
        title: "No test or suite is `.disabled`.",
        category: .testing,
        rationale: """
            A disabled test still reads as coverage while checking nothing. A failing behaviour is either fixed, or \
            asserted as a known issue that names what tracks it.
            """,
        howToFix: "Fix the code or the test. If the bug must wait, wrap the failing part in `withKnownIssue(\"…\")`.",
        badExample: "@Test(.disabled(\"flaky\")) func watchRegenerates() throws {",
        goodExample: "@Test func watchRegenerates() throws {"
    )
}

/// Every rule, in the order `docs/architecture-rules.md` lists them.
let allRules: [Rule] = [
    .modulesImportWithinTheirBudget, .pipelinePerformsNoIO, .libraryNeverTraps, .astTypesAreValues,
    .testsUseSwiftTesting, .knownIssuesExplainThemselves, .testsAreNotDisabled,
]

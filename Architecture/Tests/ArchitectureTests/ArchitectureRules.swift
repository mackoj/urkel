import LLMCheck
import Testing

/// The rules, run on the repository. A failure prints the rule, why it exists and how to fix it.
@Suite("Architecture rules")
struct ArchitectureRules {
    static func sources() throws -> Scope { try urkel().productionCode.in("/Sources") }
    static func tests() throws -> Scope { try urkel().testCode.in("/Tests") }

    /// The modules of the compiler pipeline: source text in, AST, diagnostics, Swift source or a graph out.
    static func pipeline() throws -> Scope {
        try sources().in(
            "Sources/UrkelAST", "Sources/UrkelParser", "Sources/UrkelValidation", "Sources/UrkelEmitterSwift",
            "Sources/UrkelVisualize")
    }

    @Test func modulesImportWithinTheirBudget() throws {
        let sources = try Self.sources()
        #expect(sources.in("Sources/UrkelParser").imports.count > 10)
        expectNone(Detect.importsOverBudget(in: sources), rule: .modulesImportWithinTheirBudget)
    }

    @Test func pipelinePerformsNoIO() throws {
        let pipeline = try Self.pipeline()
        #expect(pipeline.relativePaths.count > 20)
        expectNone(Detect.impureCode(in: pipeline), rule: .pipelinePerformsNoIO)
    }

    @Test func libraryNeverTraps() throws {
        expectNone(Detect.traps(in: try Self.sources()), rule: .libraryNeverTraps)
    }

    @Test func astTypesAreValues() throws {
        let ast = try Self.sources().in("Sources/UrkelAST")
        #expect(ast.structs.count > 15)
        expectNone(Detect.astTypesThatAreNotValues(in: ast), rule: .astTypesAreValues)
    }

    @Test func testsUseSwiftTesting() throws {
        let tests = try Self.tests()
        #expect(tests.containing("import Testing").relativePaths.count > 10)
        expectNone(tests.xcTestImports, rule: .testsUseSwiftTesting)
    }

    @Test func knownIssuesExplainThemselves() throws {
        expectNone(try Self.tests().unexplainedKnownIssues, rule: .knownIssuesExplainThemselves)
    }

    @Test func testsAreNotDisabled() throws {
        expectNone(try Self.tests().disabledTests, rule: .testsAreNotDisabled)
    }
}

/// Keeps `docs/architecture-rules.md` in step with the rules. Regenerate with
/// `LLM_CHECK_RECORD=1 swift test --package-path Architecture`.
@Test func rulesDocumentIsUpToDate() throws {
    let catalog = RuleCatalog(allRules)
    #expect(catalog.duplicateIDs.isEmpty)
    try expectFile(
        "docs/architecture-rules.md", in: urkel(),
        matches: catalog.markdown(
            title: "Architecture rules",
            introduction: """
                The mechanical part of `CODING_STANDARDS.md`, enforced by the `Architecture/` package with \
                [swift-llm-check](https://github.com/mackoj/swift-llm-check): \
                `swift test --package-path Architecture` (macOS). Generated from its rules; do not edit by hand.
                """))
}

import LLMCheck

/// The Urkel repository, rooted where `.llm-check.yaml` is. Its file list and every parsed file are shared by all
/// suites, which Swift Testing runs in parallel.
func urkel() throws -> Codebase { try Codebase() }

extension RuleCategory {
    static let layering = RuleCategory(
        "layering",
        description: "Which module may import what. Read before you add an `import` to `Sources`."
    )
    static let purity = RuleCategory(
        "purity",
        description: "The compiler pipeline is pure. Read before you reach for the file system, a clock or `print`."
    )
    static let errors = RuleCategory(
        "errors",
        description: "How the library reports failure. Read before you add a `try!` or a trap."
    )
    static let models = RuleCategory(
        "models",
        description: "The AST is plain data. Read before you add or change a type in `Sources/UrkelAST`."
    )
    static let testing = RuleCategory(
        "testing",
        description: "Swift Testing, and no silenced tests. Read before you add, skip or mark a test."
    )
}

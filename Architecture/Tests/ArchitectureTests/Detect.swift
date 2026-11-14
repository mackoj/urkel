import LLMCheck
import SwiftSyntax

/// The detectors, separate from the codebase so `DetectorTests` can run them on snippets.
enum Detect {
    /// What each library module may import: its dependencies in `Package.swift`, and Foundation.
    static let importBudget: [String: Set<String>] = [
        "UrkelAST": ["Foundation"],
        "UrkelParser": ["Foundation", "UrkelAST", "Parsing"],
        "UrkelValidation": ["Foundation", "UrkelAST"],
        "UrkelEmitterSwift": ["Foundation", "UrkelAST", "SwiftSyntax", "SwiftSyntaxBuilder", "SwiftParser"],
        "UrkelEmitterMustache": ["Foundation", "UrkelAST", "Mustache"],
        "UrkelVisualize": ["Foundation", "UrkelAST"],
    ]

    /// The module a file belongs to: the folder under `Sources/`.
    static func module(of file: SourceFile) -> String? {
        let components = file.pathComponents
        guard let index = components.firstIndex(of: "Sources"), index + 1 < components.count else { return nil }
        return components[index + 1]
    }

    /// Imports in a budgeted module that its budget does not list. Modules without a budget (the umbrella, the
    /// CLI, the LSP server) are not checked.
    static func importsOverBudget(in scope: Scope) -> [Match<ImportDeclSyntax>] {
        scope.imports.filter { match in
            guard let module = module(of: match.file), let allowed = importBudget[module] else { return false }
            return !allowed.contains(match.node.moduleName)
        }
    }

    /// Types whose every use is I/O, a process or shared global state.
    static let impureTypes: Set<String> = [
        "FileManager", "FileHandle", "URLSession", "ProcessInfo", "Process", "Pipe", "Bundle", "UserDefaults",
        "NotificationCenter", "DispatchQueue",
    ]

    /// Uses of I/O, a clock, randomness or `print`: `FileManager.default`, `Date()`, `Date.now`, `UUID()`,
    /// `print(x)`. `Date(timeIntervalSince1970:)` and a method named `print` on a value are pure and pass.
    static func impureCode(in scope: Scope) -> [Match<Syntax>] {
        let calls = scope.calls(named: "Date", "UUID", "print").filter { call in
            call.node.calledExpression.is(DeclReferenceExprSyntax.self)
                && (call.node.calledName == "print" || call.node.arguments.isEmpty)
        }
        let now = scope.containing("Date.now").nodes(of: MemberAccessExprSyntax.self) {
            $0.node.declName.baseName.text == "now" && $0.node.base?.trimmedDescription == "Date"
        }
        return scope.references(to: impureTypes) + calls.map(\.erased) + now.map(\.erased)
    }

    /// Calls that stop the process: `fatalError`, `precondition`, `preconditionFailure`.
    static let traps: Set<String> = ["fatalError", "precondition", "preconditionFailure"]

    /// `try!`, `as!` and calls to a trap. Text inside a string literal, such as the emitter's generated code, is
    /// not code and passes.
    static func traps(in scope: Scope) -> [Match<Syntax>] {
        let calls = scope.calls(named: traps).filter { $0.node.receiver == nil }
        let forcedTries = scope.containing("try!").nodes(of: TryExprSyntax.self) {
            $0.node.questionOrExclamationMark?.tokenKind == .exclamationMark
        }
        // The parser leaves `x as! T` inside an expression sequence unfolded, as `UnresolvedAsExprSyntax`.
        let forcedCasts = scope.containing("as!").nodes(of: UnresolvedAsExprSyntax.self) {
            $0.node.questionOrExclamationMark?.tokenKind == .exclamationMark
        }
        return calls.map(\.erased) + forcedTries.map(\.erased) + forcedCasts.map(\.erased)
    }

    /// The conformances every public AST type declares.
    static let astConformances = ["Equatable", "Sendable", "Codable"]

    /// Public structs and enums that do not declare `Equatable`, `Sendable` and `Codable`, and any class or actor.
    static func astTypesThatAreNotValues(in scope: Scope) -> [Declaration] {
        let publicValues = (scope.structs + scope.enums).withModifier("public").filter { type in
            !astConformances.allSatisfy { type.inherits(from: $0) }
        }
        return publicValues + scope.classes + scope.actors
    }

    /// `import XCTest`.
    static func xcTestImports(in scope: Scope) -> [Match<ImportDeclSyntax>] {
        scope.imports(of: "XCTest")
    }

    /// `withKnownIssue { … }` whose first argument is not a string literal: the reason.
    static func unexplainedKnownIssues(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.calls(named: "withKnownIssue").filter { call in
            guard let first = call.node.arguments.first, first.label == nil else { return true }
            return !first.expression.is(StringLiteralExprSyntax.self)
        }
    }

    /// The `.disabled(…)` trait, wherever a test or suite takes it.
    static func disabledTests(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.calls(named: "disabled").filter { call in
            call.node.receiver == nil && call.node.calledExpression.is(MemberAccessExprSyntax.self)
        }
    }
}

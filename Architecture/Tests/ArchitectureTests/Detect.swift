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

    /// Imports in a budgeted module that its budget does not list. Modules without a budget (the umbrella, the
    /// CLI, the LSP server) are not checked.
    static func importsOverBudget(in scope: Scope) -> [Match<ImportDeclSyntax>] {
        scope.imports.filter { match in
            guard let module = match.file.module, let allowed = importBudget[module] else { return false }
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
        return calls.map(\.erased) + scope.forcedTries.map(\.erased) + scope.forcedCasts
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
}

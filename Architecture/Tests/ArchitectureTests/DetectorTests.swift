import LLMCheck
import Testing

/// Each detector on snippets: it finds what its rule forbids and nothing its rule allows.
@Suite struct DetectorTests {
    func scope(_ source: String, at path: String = "Sources/UrkelParser/File.swift") -> Scope {
        Scope(files: [SourceFile(path: path, source: source)])
    }

    @Test func importsOverBudgetAreFound() {
        let found = Detect.importsOverBudget(
            in: Scope(files: [
                SourceFile(path: "Sources/UrkelAST/A.swift", source: "import Foundation\nimport Parsing"),
                SourceFile(path: "Sources/UrkelValidation/B.swift", source: "import UrkelAST\nimport UrkelParser"),
                SourceFile(path: "Sources/UrkelEmitterSwift/C.swift", source: "import Mustache"),
            ]))
        #expect(found.map(\.node.moduleName) == ["Parsing", "UrkelParser", "Mustache"])
    }

    @Test func importsWithinBudgetPass() {
        let found = Detect.importsOverBudget(
            in: Scope(files: [
                SourceFile(path: "Sources/UrkelParser/A.swift", source: "import Foundation\nimport Parsing\nimport UrkelAST"),
                SourceFile(path: "Sources/UrkelEmitterSwift/B.swift", source: "import SwiftParser\nimport SwiftSyntax"),
                SourceFile(path: "Sources/Urkel/C.swift", source: "import Dependencies\nimport LanguageServerProtocol"),
                SourceFile(path: "Sources/UrkelCLI/D.swift", source: "import ArgumentParser"),
            ]))
        #expect(found.isEmpty)
    }

    @Test func impureCodeIsFound() {
        let found = Detect.impureCode(
            in: scope(
                """
                let files = FileManager.default
                let now = Date()
                let later = Date.now
                let id = UUID()
                print("parsed")
                let bundle = Bundle.module
                """))
        #expect(found.map(\.location.line).sorted() == [1, 2, 3, 4, 5, 6])
    }

    @Test func pureCodePasses() {
        let found = Detect.impureCode(
            in: scope(
                """
                // FileManager and print() are fine in a comment.
                let message = "Date() and print() are fine in a string"
                let epoch = Date(timeIntervalSince1970: 0)
                let text = parser.printFile(file)
                printer.print(file)
                """))
        #expect(found.isEmpty)
    }

    @Test func trapsAreFound() {
        let found = Detect.traps(
            in: scope(
                """
                let duration = try! DurationParser().parse(&input)
                let name = value as! String
                fatalError("unreachable")
                precondition(!states.isEmpty)
                preconditionFailure("no init state")
                """))
        #expect(found.map(\.location.line).sorted() == [1, 2, 3, 4, 5])
    }

    @Test func handledFailuresAndGeneratedTextPass() {
        let found = Detect.traps(
            in: scope(
                #"""
                let duration = try? DurationParser().parse(&input)
                let name = value as? String
                let file = try UrkelParser.parse(source)
                let branch = "fatalError(\"Urkel emitter: no guard matched for '\(event)'\")"
                let accessor = "preconditionFailure(\"Emitter invariant\")"
                """#))
        #expect(found.isEmpty)
    }

    @Test func astTypesThatAreNotValuesAreFound() {
        let found = Detect.astTypesThatAreNotValues(
            in: scope(
                """
                public struct GuardDecl: Equatable {}
                public enum Arrow: Equatable, Sendable {}
                public final class Node: Equatable, Sendable, Codable {}
                struct Scratch {}
                """, at: "Sources/UrkelAST/A.swift"))
        #expect(found.map(\.name) == ["GuardDecl", "Arrow", "Node"])
    }

    @Test func astValueTypesPass() {
        let found = Detect.astTypesThatAreNotValues(
            in: scope(
                """
                public struct StateRef: Equatable, Sendable, Codable {
                    public enum Kind: String, Equatable, Sendable, Codable { case simple }
                }
                public enum Arrow: Equatable, Sendable, Codable { case standard }
                """, at: "Sources/UrkelAST/A.swift"))
        #expect(found.isEmpty)
    }

    @Test func xcTestImportsAreFound() {
        let found = Detect.xcTestImports(in: scope("import XCTest\nimport Testing", at: "Tests/T/A.swift"))
        #expect(found.map(\.location.line) == [1])
    }

    @Test func unexplainedKnownIssuesAreFound() {
        let found = Detect.unexplainedKnownIssues(
            in: scope(
                """
                withKnownIssue { try emit() }
                withKnownIssue(isIntermittent: true) { try emit() }
                withKnownIssue("Parallel regions are not emitted yet (US-1.12)") { try emit() }
                """, at: "Tests/T/A.swift"))
        #expect(found.map(\.location.line) == [1, 2])
    }

    @Test func disabledTestsAreFound() {
        let found = Detect.disabledTests(
            in: scope(
                """
                @Test(.disabled("flaky")) func a() {}
                @Suite(.disabled()) struct B {}
                @Test func c() { rule.disabled() }
                """, at: "Tests/T/A.swift"))
        #expect(found.map(\.location.line) == [1, 2])
    }
}

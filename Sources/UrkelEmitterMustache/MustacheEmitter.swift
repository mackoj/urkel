import Foundation
import Mustache
import UrkelAST

// MARK: - MustacheEmitter

/// Template-based emitter for Urkel v2.
///
/// Use this for customised output (different import style, naming convention,
/// non-Swift targets) by supplying a Mustache template string.
/// The primary Swift generation path is `SwiftSyntaxEmitter`.
public struct MustacheEmitter {
    public init() {}

    /// Renders the given Mustache template against the `UrkelFile`'s template context.
    public func render(file: UrkelFile, templateString: String) throws -> String {
        do {
            let template = try MustacheTemplate(string: templateString)
            return template.render(file.templateContext)
        } catch {
            throw MustacheEmitterError.invalidTemplate(String(describing: error))
        }
    }

    /// Renders using the bundled template for `language` (e.g. `"swift"`, `"kotlin"`).
    ///
    /// The template must exist at `Sources/Urkel/Templates/<language>.mustache`.
    public func render(file: UrkelFile, language: String) throws -> String {
        let templateString = try loadBundledTemplate(language: language)
        return try render(file: file, templateString: templateString)
    }

    // MARK: - Private

    private func loadBundledTemplate(language: String) throws -> String {
        // 1. Try Bundle.module (SPM resource bundle, for production use)
        if let url = Bundle.module.url(forResource: language, withExtension: "mustache") {
            return try String(contentsOf: url, encoding: .utf8)
        }
        // 2. Fallback: relative path from the source file (useful in tests without bundle)
        // #file resolves to Sources/UrkelEmitterMustache/MustacheEmitter.swift
        let sourceRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // UrkelEmitterMustache/
            .appendingPathComponent("Templates")
            .appendingPathComponent("\(language).mustache")
        if FileManager.default.fileExists(atPath: sourceRoot.path) {
            return try String(contentsOf: sourceRoot, encoding: .utf8)
        }
        throw MustacheEmitterError.templateNotFound(language)
    }
}

// MARK: - Errors

public enum MustacheEmitterError: Error, LocalizedError, Sendable {
    case invalidTemplate(String)
    case templateNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTemplate(let detail):
            return "Invalid Mustache template: \(detail)"
        case .templateNotFound(let lang):
            return "Bundled Mustache template not found for language: \(lang)"
        }
    }
}

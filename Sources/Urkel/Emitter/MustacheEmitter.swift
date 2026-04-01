import Foundation
import Mustache

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
}

// MARK: - Errors

public enum MustacheEmitterError: Error, LocalizedError, Sendable {
    case invalidTemplate(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTemplate(let detail):
            return "Invalid Mustache template: \(detail)"
        }
    }
}

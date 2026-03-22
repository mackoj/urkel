import Foundation
import Mustache

public enum TemplateCodeEmitterError: Error, LocalizedError, Sendable {
    case invalidTemplate(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTemplate(let details):
            return "Invalid template for template-based code emission: \(details)"
        }
    }
}

/// Template-based emitter used for non-Swift targets (for example Kotlin).
public struct TemplateCodeEmitter {
    public init() {}

    public func render(
        ast: MachineAST,
        templateString: String,
        templateImportsOverride: [String]? = nil
    ) throws -> String {
        do {
            let template = try MustacheTemplate(string: templateString)
            return template.render(ast.templateContext(templateImportsOverride: templateImportsOverride))
        } catch {
            throw TemplateCodeEmitterError.invalidTemplate(String(describing: error))
        }
    }
}

/// Backward-compatible alias for the template-based emitter.
public typealias MustacheExportEngine = TemplateCodeEmitter
/// Backward-compatible alias for template emitter errors.
public typealias MustacheExportError = TemplateCodeEmitterError

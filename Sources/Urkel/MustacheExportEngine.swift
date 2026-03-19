import Foundation
import Mustache

public enum MustacheExportError: Error, LocalizedError, Sendable {
    case invalidTemplate(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTemplate(let details):
            return "Invalid mustache template: \(details)"
        }
    }
}

public struct MustacheExportEngine {
    public init() {}

    public func render(ast: MachineAST, templateString: String) throws -> String {
        do {
            let template = try MustacheTemplate(string: templateString)
            return template.render(ast.dictionaryRepresentation)
        } catch {
            throw MustacheExportError.invalidTemplate(String(describing: error))
        }
    }
}

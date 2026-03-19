import Foundation

public struct UrkelDiagnostic: Equatable, Sendable {
    public let line: Int
    public let column: Int
    public let message: String
    public let severity: Int

    public init(line: Int, column: Int, message: String, severity: Int = 1) {
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
    }
}

public actor UrkelLanguageServer {
    private var documents: [String: String] = [:]

    public init() {}

    public func didOpen(uri: String, text: String) -> [UrkelDiagnostic] {
        documents[uri] = text
        return diagnostics(for: text)
    }

    public func didChange(uri: String, text: String) -> [UrkelDiagnostic] {
        documents[uri] = text
        return diagnostics(for: text)
    }

    public func diagnostics(for source: String) -> [UrkelDiagnostic] {
        do {
            let ast = try UrkelParser().parse(source: source)
            try UrkelValidator.validate(ast)
            return []
        } catch let parse as UrkelParseError {
            return [UrkelDiagnostic(line: parse.line, column: parse.column, message: parse.message)]
        } catch let validation as UrkelValidationError {
            return [UrkelDiagnostic(line: 1, column: 1, message: validation.localizedDescription)]
        } catch {
            return [UrkelDiagnostic(line: 1, column: 1, message: String(describing: error))]
        }
    }
}

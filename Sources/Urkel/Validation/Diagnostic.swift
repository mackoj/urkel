// MARK: - Source Range

/// A zero-based source location used in diagnostics.
public struct SourceRange: Sendable, Equatable {
    public struct Position: Sendable, Equatable {
        public let line: Int
        public let column: Int
        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }
    }
    public let start: Position
    public let end: Position
    public init(start: Position, end: Position) {
        self.start = start
        self.end = end
    }
}

// MARK: - Diagnostic Code

/// Structured code identifying a diagnostic category.
public enum DiagnosticCode: String, Sendable, Equatable {
    case missingInitState
    case multipleInitStates
    case missingFinalState
    case undefinedStateReference
    case undefinedEntryExitState
    case duplicateStateName
    case unreachableState
    case deadState
    case elseGuardNotLast
    case duplicateGuardBranch
    case undeclaredImportInFork
    case determinismViolation
}

// MARK: - Diagnostic

/// A single validation diagnostic.
public struct Diagnostic: Sendable, Equatable {
    public enum Severity: Sendable, Equatable {
        case error
        case warning
    }

    public var severity: Severity
    public var code: DiagnosticCode
    public var message: String
    public var range: SourceRange?

    public init(severity: Severity, code: DiagnosticCode, message: String, range: SourceRange? = nil) {
        self.severity = severity
        self.code = code
        self.message = message
        self.range = range
    }
}

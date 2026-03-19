public struct MachineAST: Equatable, Sendable {
    public struct SourceLocation: Equatable, Sendable {
        public let line: Int
        public let column: Int

        public init(line: Int, column: Int) {
            self.line = line
            self.column = column
        }
    }

    public struct SourceRange: Equatable, Sendable {
        public let start: SourceLocation
        public let end: SourceLocation

        public init(start: SourceLocation, end: SourceLocation) {
            self.start = start
            self.end = end
        }
    }

    public struct Factory: Equatable, Sendable {
        public let name: String
        public let parameters: [Parameter]
        public let range: SourceRange?

        public init(name: String, parameters: [Parameter], range: SourceRange? = nil) {
            self.name = name
            self.parameters = parameters
            self.range = range
        }
    }

    public struct Parameter: Equatable, Sendable {
        public let name: String
        public let type: String
        public let range: SourceRange?

        public init(name: String, type: String, range: SourceRange? = nil) {
            self.name = name
            self.type = type
            self.range = range
        }
    }

    public struct StateNode: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case initial
            case normal
            case terminal
        }

        public let name: String
        public let kind: Kind
        public let range: SourceRange?

        public init(name: String, kind: Kind, range: SourceRange? = nil) {
            self.name = name
            self.kind = kind
            self.range = range
        }
    }

    public struct TransitionNode: Equatable, Sendable {
        public let from: String
        public let event: String
        public let parameters: [Parameter]
        public let to: String
        public let range: SourceRange?

        public init(from: String, event: String, parameters: [Parameter], to: String, range: SourceRange? = nil) {
            self.from = from
            self.event = event
            self.parameters = parameters
            self.to = to
            self.range = range
        }
    }

    public let imports: [String]
    public let machineName: String
    public let contextType: String?
    public let factory: Factory?
    public let states: [StateNode]
    public let transitions: [TransitionNode]
    public let range: SourceRange?

    public init(
        imports: [String],
        machineName: String,
        contextType: String?,
        factory: Factory?,
        states: [StateNode],
        transitions: [TransitionNode],
        range: SourceRange? = nil
    ) {
        self.imports = imports
        self.machineName = machineName
        self.contextType = contextType
        self.factory = factory
        self.states = states
        self.transitions = transitions
        self.range = range
    }
}

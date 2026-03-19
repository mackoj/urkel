public struct MachineAST: Equatable, Sendable {
    public struct Factory: Equatable, Sendable {
        public let name: String
        public let parameters: [Parameter]

        public init(name: String, parameters: [Parameter]) {
            self.name = name
            self.parameters = parameters
        }
    }

    public struct Parameter: Equatable, Sendable {
        public let name: String
        public let type: String

        public init(name: String, type: String) {
            self.name = name
            self.type = type
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

        public init(name: String, kind: Kind) {
            self.name = name
            self.kind = kind
        }
    }

    public struct TransitionNode: Equatable, Sendable {
        public let from: String
        public let event: String
        public let parameters: [Parameter]
        public let to: String

        public init(from: String, event: String, parameters: [Parameter], to: String) {
            self.from = from
            self.event = event
            self.parameters = parameters
            self.to = to
        }
    }

    public let imports: [String]
    public let machineName: String
    public let contextType: String?
    public let factory: Factory?
    public let states: [StateNode]
    public let transitions: [TransitionNode]

    public init(
        imports: [String],
        machineName: String,
        contextType: String?,
        factory: Factory?,
        states: [StateNode],
        transitions: [TransitionNode]
    ) {
        self.imports = imports
        self.machineName = machineName
        self.contextType = contextType
        self.factory = factory
        self.states = states
        self.transitions = transitions
    }
}

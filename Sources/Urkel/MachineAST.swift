public struct MachineAST: Equatable, Sendable {
    public struct EmitterOptions: Equatable, Sendable {
        public let swiftImports: [String]?
        public let templateImports: [String]?

        public init(
            swiftImports: [String]? = nil,
            templateImports: [String]? = nil
        ) {
            self.swiftImports = swiftImports
            self.templateImports = templateImports
        }
    }

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

    public struct DocComment: Equatable, Sendable {
        public let text: String
        public let range: SourceRange?

        public init(text: String, range: SourceRange? = nil) {
            self.text = text
            self.range = range
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
        public let docComments: [DocComment]

        public init(
            name: String,
            kind: Kind,
            range: SourceRange? = nil,
            docComments: [DocComment] = []
        ) {
            self.name = name
            self.kind = kind
            self.range = range
            self.docComments = docComments
        }
    }

    public struct TransitionNode: Equatable, Sendable {
        public let from: String
        public let event: String
        public let parameters: [Parameter]
        public let to: String?
        public let spawnedMachine: String?
        public let range: SourceRange?
        public let docComments: [DocComment]

        public init(
            from: String,
            event: String,
            parameters: [Parameter],
            to: String?,
            spawnedMachine: String? = nil,
            range: SourceRange? = nil,
            docComments: [DocComment] = []
        ) {
            self.from = from
            self.event = event
            self.parameters = parameters
            self.to = to
            self.spawnedMachine = spawnedMachine
            self.range = range
            self.docComments = docComments
        }
    }

    public let imports: [String]
    public let machineName: String
    public let contextType: String?
    public let factory: Factory?
    public let composedMachines: [String]
    public let states: [StateNode]
    public let transitions: [TransitionNode]
    public let emitterOptions: EmitterOptions?
    public let continuations: [String: String]
    public let range: SourceRange?

    public init(
        imports: [String],
        machineName: String,
        contextType: String?,
        factory: Factory?,
        composedMachines: [String] = [],
        states: [StateNode],
        transitions: [TransitionNode],
        emitterOptions: EmitterOptions? = nil,
        continuations: [String: String] = [:],
        range: SourceRange? = nil
    ) {
        self.imports = imports
        self.machineName = machineName
        self.contextType = contextType
        self.factory = factory
        self.composedMachines = composedMachines
        self.states = states
        self.transitions = transitions
        self.emitterOptions = emitterOptions
        self.continuations = continuations
        self.range = range
    }
}

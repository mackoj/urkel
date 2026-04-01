// MARK: - Parallel declarations

/// A single `region` within a `@parallel` block.
public struct RegionDecl: Equatable, Sendable, Codable {
    public let name: String
    public let states: [StateDecl]
    public let transitions: [TransitionStmt]

    public init(
        name: String,
        states: [StateDecl] = [],
        transitions: [TransitionStmt] = []
    ) {
        self.name        = name
        self.states      = states
        self.transitions = transitions
    }
}

/// A `@parallel Name` declaration containing one or more regions.
public struct ParallelDecl: Equatable, Sendable, Codable {
    public let name: String
    public let regions: [RegionDecl]
    public let docComments: [DocComment]

    public init(
        name: String,
        regions: [RegionDecl] = [],
        docComments: [DocComment] = []
    ) {
        self.name        = name
        self.regions     = regions
        self.docComments = docComments
    }
}

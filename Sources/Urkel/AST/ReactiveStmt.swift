// MARK: - Reactive source

/// The machine or parallel-region target of an `@on` declaration.
public enum ReactiveTarget: Equatable, Sendable, Codable {
    /// `@on MachineName::State` — reacts to a sub-machine state.
    case machine(String)
    /// `@on ParallelName.RegionName::State` — reacts to a parallel region state.
    case region(parallel: String, region: String)
}

/// The state being observed in an `@on` declaration.
public enum ReactiveState: Equatable, Sendable, Codable {
    case named(String)
    case `init`
    case final
    /// `*` — any state change.
    case any
}

/// The complete source of a reactive `@on` declaration.
public struct ReactiveSource: Equatable, Sendable, Codable {
    public let target: ReactiveTarget
    public let state: ReactiveState

    public init(target: ReactiveTarget, state: ReactiveState) {
        self.target = target
        self.state = state
    }
}

// MARK: - Reactive statement

/// An `@on` reactive declaration: reacts to a sub-machine or region entering a state.
public struct ReactiveStmt: Equatable, Sendable, Codable {
    public let source: ReactiveSource
    /// Optional AND condition: `@on Sub::State, OwnState -> Dest`.
    public let ownState: String?
    public let arrow: Arrow
    /// `nil` for in-place reactions (`-*>`).
    public let destination: StateRef?
    public let action: ActionClause?
    public let docComments: [DocComment]

    public init(
        source: ReactiveSource,
        ownState: String? = nil,
        arrow: Arrow = .standard,
        destination: StateRef? = nil,
        action: ActionClause? = nil,
        docComments: [DocComment] = []
    ) {
        self.source      = source
        self.ownState    = ownState
        self.arrow       = arrow
        self.destination = destination
        self.action      = action
        self.docComments = docComments
    }
}

// MARK: - Top-level transition declaration

/// A transition or reactive declaration in the `@transitions` block.
public enum TransitionDecl: Equatable, Sendable, Codable {
    case transition(TransitionStmt)
    case reactive(ReactiveStmt)
}

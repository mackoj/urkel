/// Whether a state is the initial, a regular, or a terminal node.
public enum StateKind: String, Equatable, Sendable, Codable {
    case `init`
    case state
    case final
}

/// Shallow vs. deep history modifier on a compound state.
public enum HistoryModifier: Equatable, Sendable, Codable {
    /// `@history` — restore last direct child on re-entry.
    case shallow
    /// `@history(deep)` — restore full active subtree on re-entry.
    case deep
}

// MARK: - Simple state

/// A flat (non-hierarchical) state declaration.
///
/// All three `StateKind` values support optional parameters:
/// - `init(params) Name` — construction-time inputs (US-1.3)
/// - `state Name(params)` — state-carried data (US-1.19)
/// - `final Name(params)` — typed terminal output (US-1.5)
public struct SimpleStateDecl: Equatable, Sendable, Codable {
    public let kind: StateKind
    /// Parameters declared on this state — may be empty.
    public let params: [Parameter]
    public let name: String
    public let history: HistoryModifier?
    public let docComments: [DocComment]

    public init(
        kind: StateKind,
        params: [Parameter] = [],
        name: String,
        history: HistoryModifier? = nil,
        docComments: [DocComment] = []
    ) {
        self.kind = kind
        self.params = params
        self.name = name
        self.history = history
        self.docComments = docComments
    }
}

// MARK: - Compound state

/// A hierarchical state containing child states and inner transitions.
public struct CompoundStateDecl: Equatable, Sendable, Codable {
    public let name: String
    public let history: HistoryModifier?
    /// Direct child states (flat within this compound).
    public let children: [SimpleStateDecl]
    /// Transitions scoped to this compound's sub-space.
    public let innerTransitions: [TransitionStmt]
    public let docComments: [DocComment]

    public init(
        name: String,
        history: HistoryModifier? = nil,
        children: [SimpleStateDecl] = [],
        innerTransitions: [TransitionStmt] = [],
        docComments: [DocComment] = []
    ) {
        self.name = name
        self.history = history
        self.children = children
        self.innerTransitions = innerTransitions
        self.docComments = docComments
    }
}

// MARK: - State declaration (sum type)

/// A state declaration — either a flat simple state or a compound (hierarchical) state.
public enum StateDecl: Equatable, Sendable, Codable {
    case simple(SimpleStateDecl)
    case compound(CompoundStateDecl)

    /// The state's primary name.
    public var name: String {
        switch self {
        case .simple(let s):   return s.name
        case .compound(let c): return c.name
        }
    }

    /// The doc comments attached to this declaration.
    public var docComments: [DocComment] {
        switch self {
        case .simple(let s):   return s.docComments
        case .compound(let c): return c.docComments
        }
    }
}

// MARK: - Duration

/// Units for `after(duration)` timer declarations.
public enum DurationUnit: String, Equatable, Sendable, Codable {
    case ms
    case s
    case min
}

/// A concrete duration value used in `after(Ns)` transitions.
public struct Duration: Equatable, Sendable, Codable {
    public let value: Double
    public let unit: DurationUnit

    public init(value: Double, unit: DurationUnit) {
        self.value = value
        self.unit = unit
    }

    /// Duration in seconds.
    public var seconds: Double {
        switch unit {
        case .ms:  return value / 1000
        case .s:   return value
        case .min: return value * 60
        }
    }
}

// MARK: - Event / Timer / Always

/// The payload of a regular caller-driven event.
public struct EventDecl: Equatable, Sendable, Codable {
    public let name: String
    public let params: [Parameter]

    public init(name: String, params: [Parameter] = []) {
        self.name = name
        self.params = params
    }
}

/// A timer declaration: `after(30s)` with optional forwarded parameters.
public struct TimerDecl: Equatable, Sendable, Codable {
    public let duration: Duration
    /// Parameters forwarded to the destination state (GAP-7 resolution).
    public let params: [Parameter]

    public init(duration: Duration, params: [Parameter] = []) {
        self.duration = duration
        self.params = params
    }
}

/// The event or timer position in a transition statement.
public enum EventOrTimer: Equatable, Sendable, Codable {
    case event(EventDecl)
    case timer(TimerDecl)
    /// Eventless — fires automatically on state entry.
    case always
}

// MARK: - Guard

/// A guard clause on a transition.
public enum GuardClause: Equatable, Sendable, Codable {
    /// `[guardName]` — fires when the predicate returns `true`.
    case named(String)
    /// `[!guardName]` — fires when the predicate returns `false`.
    case negated(String)
    /// `[else]` — fires when no preceding guard matched.
    case `else`
}

// MARK: - Action

/// A list of action names declared with `/ action1, action2`.
public struct ActionClause: Equatable, Sendable, Codable {
    public let actions: [String]

    public init(actions: [String]) {
        self.actions = actions
    }
}

// MARK: - Fork

/// A single binding in a fork clause: `param: source`.
public struct ForkBinding: Equatable, Sendable, Codable {
    /// The destination sub-machine's init parameter name.
    public let param: String
    /// The source name — an event param or source state param.
    public let source: String

    public init(param: String, source: String) {
        self.param = param
        self.source = source
    }
}

/// A fork side-effect on a transition: `=> MachineName.init(bindings…)`.
public struct ForkClause: Equatable, Sendable, Codable {
    public let machine: String
    public let bindings: [ForkBinding]

    public init(machine: String, bindings: [ForkBinding] = []) {
        self.machine = machine
        self.bindings = bindings
    }
}

// MARK: - Transition source

/// The source side of a transition — either a named state or the wildcard `*`.
public enum TransitionSource: Equatable, Sendable, Codable {
    case state(StateRef)
    case wildcard
}

// MARK: - Arrow

/// The arrow kind: `->` (standard) or `-*>` (internal / in-place).
public enum Arrow: Equatable, Sendable, Codable {
    case standard
    case `internal`
}

// MARK: - Transition statement

/// A single transition or internal-transition declaration.
public struct TransitionStmt: Equatable, Sendable, Codable {
    public let source: TransitionSource
    public let arrow: Arrow
    public let event: EventOrTimer
    public let `guard`: GuardClause?
    /// `nil` on `-*>` without destination (output events, in-place handlers).
    public let destination: StateRef?
    public let fork: ForkClause?
    public let action: ActionClause?
    public let docComments: [DocComment]

    public init(
        source: TransitionSource,
        arrow: Arrow = .standard,
        event: EventOrTimer,
        guard guardClause: GuardClause? = nil,
        destination: StateRef? = nil,
        fork: ForkClause? = nil,
        action: ActionClause? = nil,
        docComments: [DocComment] = []
    ) {
        self.source      = source
        self.arrow       = arrow
        self.event       = event
        self.`guard`     = guardClause
        self.destination = destination
        self.fork        = fork
        self.action      = action
        self.docComments = docComments
    }

    /// `true` when this is an output event: internal arrow with no action.
    public var isOutputEvent: Bool {
        arrow == .internal && action == nil
    }

    /// `true` when this is an in-place handler: internal arrow with an action.
    public var isInPlaceHandler: Bool {
        arrow == .internal && action != nil
    }
}

// MARK: - Entry/Exit hooks

/// Whether the hook fires on state entry or exit.
public enum HookKind: String, Equatable, Sendable, Codable {
    case entry
    case exit
}

/// An `@entry` or `@exit` lifecycle declaration.
///
///     @entry Loading / showSpinner
///     @exit  Loading / hideSpinner
public struct EntryExitDecl: Equatable, Sendable, Codable {
    public let hook: HookKind
    /// The state this hook is attached to (may be dot-qualified for compound states).
    public let state: StateRef
    /// The action names declared after `/`.
    public let actions: [String]

    public init(hook: HookKind, state: StateRef, actions: [String]) {
        self.hook    = hook
        self.state   = state
        self.actions = actions
    }
}

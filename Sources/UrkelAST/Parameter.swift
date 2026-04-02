/// A named, typed parameter — shared across states, events, timers, and forks.
///
/// The `typeExpr` field is a verbatim host-language type string; the DSL
/// never interprets it.
public struct Parameter: Equatable, Sendable, Codable {
    /// The argument label. For example, `"device"` in `device: Peripheral`.
    public let label: String
    /// The raw type expression. For example, `"[String: Any]?"`.
    public let typeExpr: String

    public init(label: String, typeExpr: String) {
        self.label = label
        self.typeExpr = typeExpr
    }
}

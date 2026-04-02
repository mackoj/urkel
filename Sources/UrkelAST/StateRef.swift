/// A dot-qualified reference to a state — e.g., `"Active.Playing"` is
/// represented as `StateRef(components: ["Active", "Playing"])`.
public struct StateRef: Equatable, Sendable, Codable {
    public let components: [String]

    public init(_ components: [String]) {
        self.components = components
    }

    /// Convenience for a single-component reference.
    public init(_ name: String) {
        self.components = [name]
    }

    /// The dot-joined name: `"Active.Playing"`.
    public var name: String {
        components.joined(separator: ".")
    }
}

/// `DocComment` — a single `## …` documentation line attached to a declaration.
public struct DocComment: Equatable, Sendable, Codable {
    /// The comment text with the `## ` prefix stripped.
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

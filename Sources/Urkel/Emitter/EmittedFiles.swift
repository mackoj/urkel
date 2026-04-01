/// The three Swift source files produced for a single `.urkel` machine.
///
/// Each field is a complete, ready-to-write Swift source string.
public struct EmittedFiles: Sendable {
    /// `XxxMachine.swift` — phase namespace, machine struct, transition
    /// extensions, combined state enum with borrowing accessors.
    public let stateMachine: String
    /// `XxxClient.swift` — runtime builder and injectable client struct.
    public let client: String
    /// `XxxClient+Dependency.swift` — `DependencyKey` + `DependencyValues`.
    public let dependency: String

    public init(stateMachine: String, client: String, dependency: String) {
        self.stateMachine = stateMachine
        self.client       = client
        self.dependency   = dependency
    }
}

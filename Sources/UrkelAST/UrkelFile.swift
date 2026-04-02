/// `ImportDecl` — an `@import` declaration for sub-machine dependencies.
///
///     @import BLE                       — local import
///     @import Analytics from AnalyticsKit — external import
public struct ImportDecl: Equatable, Sendable, Codable {
    /// The sub-machine name.
    public let name: String
    /// The external package name, if any (`from PackageName`).
    public let from: String?
    public let docComments: [DocComment]

    public init(name: String, from: String? = nil, docComments: [DocComment] = []) {
        self.name        = name
        self.from        = from
        self.docComments = docComments
    }
}

// MARK: - Invariant

/// A single invariant declaration inside `@invariants`.
public struct InvariantDecl: Equatable, Sendable, Codable {
    public let expression: String
    public let docComments: [DocComment]

    public init(expression: String, docComments: [DocComment] = []) {
        self.expression  = expression
        self.docComments = docComments
    }
}

// MARK: - Root node

/// The root in-memory representation of a parsed `.urkel` file.
///
/// This is the single source of truth consumed by the validator, emitter,
/// and visualiser. Every field maps directly to a grammar construct in
/// `grammar.ebnf`.
///
/// Source-range metadata is intentionally excluded from `Equatable` equality
/// (US-3.3 design decision: two structurally identical ASTs are equal even if
/// they came from different source locations).
public struct UrkelFile: Equatable, Sendable, Codable {
    /// The machine name from `machine Foo` or `machine Foo: Context`.
    public let machineName: String
    /// The optional context type from `machine Foo: FooContext`.
    public let contextType: String?
    /// Doc comments attached to the machine declaration.
    public let docComments: [DocComment]
    /// `@import` declarations.
    public let imports: [ImportDecl]
    /// `@parallel` declarations.
    public let parallels: [ParallelDecl]
    /// All state declarations (simple and compound).
    public let states: [StateDecl]
    /// `@entry` / `@exit` lifecycle hooks.
    public let entryExitHooks: [EntryExitDecl]
    /// All transitions (regular and reactive).
    public let transitions: [TransitionDecl]
    /// Invariant declarations from the `@invariants` block.
    public let invariants: [InvariantDecl]

    public init(
        machineName: String,
        contextType: String? = nil,
        docComments: [DocComment] = [],
        imports: [ImportDecl] = [],
        parallels: [ParallelDecl] = [],
        states: [StateDecl] = [],
        entryExitHooks: [EntryExitDecl] = [],
        transitions: [TransitionDecl] = [],
        invariants: [InvariantDecl] = []
    ) {
        self.machineName    = machineName
        self.contextType    = contextType
        self.docComments    = docComments
        self.imports        = imports
        self.parallels      = parallels
        self.states         = states
        self.entryExitHooks = entryExitHooks
        self.transitions    = transitions
        self.invariants     = invariants
    }
}

// MARK: - Convenience accessors

public extension UrkelFile {
    /// All simple (non-compound) states from the `@states` block.
    var simpleStates: [SimpleStateDecl] {
        states.compactMap {
            guard case .simple(let s) = $0 else { return nil }
            return s
        }
    }

    /// The `init` state (exactly one per machine).
    var initState: SimpleStateDecl? {
        simpleStates.first { $0.kind == .`init` }
    }

    /// All `final` states.
    var finalStates: [SimpleStateDecl] {
        simpleStates.filter { $0.kind == .final }
    }

    /// All plain `TransitionStmt` values (excludes reactive stmts).
    var transitionStmts: [TransitionStmt] {
        transitions.compactMap {
            guard case .transition(let t) = $0 else { return nil }
            return t
        }
    }

    /// All `ReactiveStmt` values.
    var reactiveStmts: [ReactiveStmt] {
        transitions.compactMap {
            guard case .reactive(let r) = $0 else { return nil }
            return r
        }
    }
}

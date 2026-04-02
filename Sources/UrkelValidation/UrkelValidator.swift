import Foundation
import UrkelAST

/// Thrown by `UrkelValidator.validateThrowing` when error-severity diagnostics exist.
public struct UrkelValidationError: Error, LocalizedError, Sendable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

// MARK: - Validator

/// v2 semantic validator — operates on a `UrkelFile` and returns `[Diagnostic]`.
public struct UrkelValidator {

    /// Validate a UrkelFile. Returns all diagnostics (empty = valid).
    public static func validate(_ file: UrkelFile) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []

        // Collect state names and check for duplicates
        var stateNames: [String] = []
        var seenNames: Set<String> = []
        collectStateNames(from: file.states, into: &stateNames, seen: &seenNames, diagnostics: &diagnostics)
        let stateSet = Set(stateNames)

        // 1. Exactly one init state (outer machine only — parallel regions have their own scopes)
        let outerSimpleStates = file.states.compactMap { if case .simple(let s) = $0 { return s } else { return nil } }
        let initStates = outerSimpleStates.filter { $0.kind == .`init` }
        if initStates.isEmpty {
            diagnostics.append(Diagnostic(
                severity: .error,
                code: .missingInitState,
                message: "Machine is missing exactly one initial state."
            ))
        } else if initStates.count > 1 {
            diagnostics.append(Diagnostic(
                severity: .error,
                code: .multipleInitStates,
                message: "Machine has multiple initial states."
            ))
        }

        // 2. At least one final state (warning - optional, skip for now to avoid noise)
        // finalStateCheck is intentionally omitted to keep diagnostics clean

        // 3. Transition state reference checks
        for t in file.transitionStmts {
            if case .state(let ref) = t.source {
                let name = ref.components.joined(separator: ".")
                if !stateSet.contains(name) {
                    diagnostics.append(Diagnostic(
                        severity: .error,
                        code: .undefinedStateReference,
                        message: "Unresolved state reference: \(name)"
                    ))
                }
            }
            if let dest = t.destination {
                let name = dest.components.joined(separator: ".")
                if !stateSet.contains(name) {
                    diagnostics.append(Diagnostic(
                        severity: .error,
                        code: .undefinedStateReference,
                        message: "Unresolved state reference: \(name)"
                    ))
                }
            }
        }

        // 4. Entry/exit hook reference checks
        for hook in file.entryExitHooks {
            let name = hook.state.name
            if !stateSet.contains(name) {
                diagnostics.append(Diagnostic(
                    severity: .error,
                    code: .undefinedEntryExitState,
                    message: "Unresolved state reference in @\(hook.hook.rawValue): \(name)"
                ))
            }
        }

        // 5. Fork import check
        for t in file.transitionStmts {
            if let fork = t.fork {
                let importedNames = Set(file.imports.map(\.name))
                if !importedNames.contains(fork.machine) {
                    diagnostics.append(Diagnostic(
                        severity: .error,
                        code: .undeclaredImportInFork,
                        message: "Fork references '\(fork.machine)' which is not declared with @import"
                    ))
                }
            }
        }

        // 6. Unreachable states (BFS from init)
        if let initState = file.initState, !stateNames.isEmpty {
            var reachable: Set<String> = [initState.name]
            var queue = [initState.name]
            let transitions = file.transitionStmts

            while !queue.isEmpty {
                let current = queue.removeFirst()
                for t in transitions {
                    var fromCurrent = false
                    switch t.source {
                    case .state(let r) where r.components.joined(separator: ".") == current:
                        fromCurrent = true
                    case .wildcard:
                        fromCurrent = true
                    default:
                        break
                    }
                    if fromCurrent, let dest = t.destination {
                        let destName = dest.components.joined(separator: ".")
                        if !reachable.contains(destName) {
                            reachable.insert(destName)
                            queue.append(destName)
                        }
                    }
                }
            }

            for name in stateNames where !reachable.contains(name) {
                diagnostics.append(Diagnostic(
                    severity: .warning,
                    code: .unreachableState,
                    message: "Unreachable state: \(name)"
                ))
            }
        }

        // 7. Dead states intentionally omitted to keep diagnostics clean

        return diagnostics
    }

    /// Throws if any error-severity diagnostics are present.
    public static func validateThrowing(_ file: UrkelFile) throws {
        let errors = validate(file).filter { $0.severity == .error }
        if let first = errors.first {
            throw UrkelValidationError(first.message)
        }
    }

    // MARK: - Private helpers

    private static func collectStateNames(
        from states: [StateDecl],
        into names: inout [String],
        seen: inout Set<String>,
        diagnostics: inout [Diagnostic]
    ) {
        for decl in states {
            let name: String
            switch decl {
            case .simple(let s):
                name = s.name
                if seen.contains(name) {
                    diagnostics.append(Diagnostic(
                        severity: .error,
                        code: .duplicateStateName,
                        message: "Duplicate state declaration: \(name)"
                    ))
                } else {
                    seen.insert(name)
                    names.append(name)
                }
            case .compound(let c):
                name = c.name
                if seen.contains(name) {
                    diagnostics.append(Diagnostic(
                        severity: .error,
                        code: .duplicateStateName,
                        message: "Duplicate state declaration: \(name)"
                    ))
                } else {
                    seen.insert(name)
                    names.append(name)
                }
                // Also collect children
                for child in c.children {
                    let childName = child.name
                    if seen.contains(childName) {
                        diagnostics.append(Diagnostic(
                            severity: .error,
                            code: .duplicateStateName,
                            message: "Duplicate state declaration: \(childName)"
                        ))
                    } else {
                        seen.insert(childName)
                        names.append(childName)
                    }
                }
            }
        }
    }
}

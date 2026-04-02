import Foundation
import Parsing
import UrkelAST

/// Parse error produced by the Urkel parser.
public struct UrkelParseError: Error, LocalizedError, Sendable, Equatable {
    public let message: String
    public let line: Int
    public let column: Int?

    public init(message: String, line: Int = 0, column: Int? = nil) {
        self.message = message
        self.line = line
        self.column = column
    }

    public var errorDescription: String? {
        if let column {
            return "Parse error at line \(line), column \(column): \(message)"
        }
        return "Parse error at line \(line): \(message)"
    }
}

// MARK: - Public Parser API

/// The Urkel parser — produces a `UrkelFile` from `.urkel` source text.
/// Uses swift-parsing composable parser-combinators throughout.
public struct UrkelParser {
    public init() {}

    /// Parse `.urkel` source text into a `UrkelFile` AST.
    public static func parse(_ source: String) throws -> UrkelFile {
        try UrkelParser().parse(source: source, machineNameFallback: nil)
    }

    /// Instance parse method — for compatibility with generator.
    public func parse(source: String, machineNameFallback: String? = nil) throws -> UrkelFile {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        var input = normalized[...]
        do {
            return try FileParser(machineNameFallback: machineNameFallback).parse(&input)
        } catch let e as UrkelParseError {
            throw e
        } catch {
            throw UrkelParseError(message: error.localizedDescription, line: 0)
        }
    }

    /// Format source text in canonical form (re-parse and re-print).
    public func format(_ source: String) -> String {
        guard let file = try? parse(source: source) else { return source }
        return printFile(file)
    }

    /// Canonical printer for a `UrkelFile`.
    public func printFile(_ file: UrkelFile) -> String {
        var lines: [String] = []

        if let ctx = file.contextType {
            lines.append("machine \(file.machineName): \(ctx)")
        } else {
            lines.append("machine \(file.machineName)")
        }

        for imp in file.imports {
            if let from = imp.from {
                lines.append("@import \(imp.name) from \(from)")
            } else {
                lines.append("@import \(imp.name)")
            }
        }

        lines.append("@states")
        for state in file.states {
            lines.append(printStateDecl(state, indent: "  "))
        }

        for hook in file.entryExitHooks {
            let actions = hook.actions.joined(separator: ", ")
            lines.append("@\(hook.hook.rawValue) \(hook.state.name) / \(actions)")
        }

        if !file.transitions.isEmpty {
            lines.append("@transitions")
            for t in file.transitions {
                switch t {
                case .transition(let ts):
                    lines.append("  \(printTransitionStmt(ts))")
                case .reactive(let rs):
                    lines.append("  \(printReactiveStmt(rs))")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func printStateDecl(_ decl: StateDecl, indent: String) -> String {
        switch decl {
        case .simple(let s):
            let docs = s.docComments.map { "\(indent)## \($0.text)" }.joined(separator: "\n")
            let stateLine = indent + printSimpleState(s)
            return docs.isEmpty ? stateLine : docs + "\n" + stateLine
        case .compound(let c):
            let docs = c.docComments.map { "\(indent)## \($0.text)" }.joined(separator: "\n")
            let hist = c.history == nil ? "" : c.history == .deep ? " @history(deep)" : " @history"
            var ls = ["\(indent)state \(c.name)\(hist) {"]
            for child in c.children { ls.append(printStateDecl(.simple(child), indent: indent + "  ")) }
            for t in c.innerTransitions { ls.append("\(indent)  \(printTransitionStmt(t))") }
            ls.append("\(indent)}")
            let block = ls.joined(separator: "\n")
            return docs.isEmpty ? block : docs + "\n" + block
        }
    }

    private func printSimpleState(_ s: SimpleStateDecl) -> String {
        let hist = s.history == nil ? "" : s.history == .deep ? " @history(deep)" : " @history"
        if s.params.isEmpty { return "\(s.kind.rawValue) \(s.name)\(hist)" }
        let ps = s.params.map { "\($0.label): \($0.typeExpr)" }.joined(separator: ", ")
        switch s.kind {
        case .state:          return "state \(s.name)(\(ps))\(hist)"
        case .`init`, .final: return "\(s.kind.rawValue)(\(ps)) \(s.name)\(hist)"
        }
    }

    private func printTransitionStmt(_ t: TransitionStmt) -> String {
        var parts: [String] = []
        switch t.source {
        case .state(let r): parts.append(r.name)
        case .wildcard:     parts.append("*")
        }
        let arrowStr = t.arrow == .standard ? "->" : "-*>"
        var eventStr: String
        switch t.event {
        case .event(let e):
            if e.params.isEmpty {
                eventStr = e.name
            } else {
                let ps = e.params.map { "\($0.label): \($0.typeExpr)" }.joined(separator: ", ")
                eventStr = "\(e.name)(\(ps))"
            }
        case .timer(let tm):
            eventStr = "after(\(tm.duration.value)\(tm.duration.unit.rawValue))"
        case .always:
            eventStr = "always"
        }
        parts.append("\(arrowStr) \(eventStr)")
        if let g = t.guard {
            switch g {
            case .named(let n):   parts.append("[\(n)]")
            case .negated(let n): parts.append("[!\(n)]")
            case .else:           parts.append("[else]")
            }
        }
        if let dest = t.destination { parts.append("-> \(dest.name)") }
        if let f = t.fork { parts.append("=> \(f.machine).init") }
        if let a = t.action { parts.append("/ \(a.actions.joined(separator: ", "))") }
        return parts.joined(separator: " ")
    }

    private func printReactiveStmt(_ r: ReactiveStmt) -> String {
        let targetStr: String
        switch r.source.target {
        case .machine(let m): targetStr = m
        case .region(let p, let rg): targetStr = "\(p).\(rg)"
        }
        let stateStr: String
        switch r.source.state {
        case .named(let n): stateStr = n
        case .`init`:       stateStr = "init"
        case .final:        stateStr = "final"
        case .any:          stateStr = "*"
        }
        let own = r.ownState.map { ", \($0)" } ?? ""
        let arrowStr = r.arrow == .standard ? "->" : "-*>"
        let destStr = r.destination.map { " \($0.name)" } ?? ""
        let actionStr = r.action.map { " / \($0.actions.joined(separator: ", "))" } ?? ""
        return "@on \(targetStr)::\(stateStr)\(own) \(arrowStr)\(destStr)\(actionStr)"
    }
}

// MARK: - File-level Parser

/// Internal parser that consumes the normalised source Substring and produces a UrkelFile.
private struct FileParser: Parser {
    let machineNameFallback: String?

    private enum Section {
        case preamble, states, transitions, invariants
        case parallelStates, parallelTransitions
    }

    func parse(_ input: inout Substring) throws -> UrkelFile {
        var machineName = machineNameFallback ?? "Machine"
        var contextType: String?
        var pendingDocComments: [DocComment] = []
        var imports: [ImportDecl] = []
        var states: [StateDecl] = []
        var transitions: [TransitionDecl] = []
        var entryExitHooks: [EntryExitDecl] = []
        var section: Section = .preamble
        var machineDocComments: [DocComment] = []

        // Compound state tracking
        var inCompound = false
        var currentCompoundName = ""
        var currentCompoundHistory: HistoryModifier? = nil
        var currentCompoundDocs: [DocComment] = []
        var currentCompoundChildren: [SimpleStateDecl] = []
        var currentCompoundTransitions: [TransitionStmt] = []

        // Parallel tracking
        var parallels: [ParallelDecl] = []
        var inParallel = false
        var currentParallelName = ""
        var currentParallelDocs: [DocComment] = []
        var currentParallelRegions: [RegionDecl] = []
        var currentRegionName = ""
        var currentRegionStates: [StateDecl] = []
        var currentRegionTransitions: [TransitionStmt] = []

        func finalizeCompound() {
            guard inCompound && !currentCompoundName.isEmpty else { return }
            states.append(.compound(CompoundStateDecl(
                name: currentCompoundName,
                history: currentCompoundHistory,
                children: currentCompoundChildren,
                innerTransitions: currentCompoundTransitions,
                docComments: currentCompoundDocs
            )))
            inCompound = false
            currentCompoundName = ""
            currentCompoundHistory = nil
            currentCompoundChildren = []
            currentCompoundTransitions = []
            currentCompoundDocs = []
        }

        func finalizeRegion() {
            guard !currentRegionName.isEmpty else { return }
            currentParallelRegions.append(RegionDecl(
                name: currentRegionName,
                states: currentRegionStates,
                transitions: currentRegionTransitions
            ))
            currentRegionName = ""
            currentRegionStates = []
            currentRegionTransitions = []
        }

        func finalizeParallel() {
            finalizeRegion()
            guard !currentParallelName.isEmpty else { return }
            parallels.append(ParallelDecl(
                name: currentParallelName,
                regions: currentParallelRegions,
                docComments: currentParallelDocs
            ))
            inParallel = false
            currentParallelName = ""
            currentParallelRegions = []
            currentParallelDocs = []
        }

        var lineNum = 0

        while !input.isEmpty {
            lineNum += 1
            let rawLine = consumeLine(&input)
            let indent = rawLine.prefix(while: { $0 == " " }).count
            let trimmed = String(rawLine.drop(while: { $0 == " " || $0 == "\t" }))
                .trimmingCharacters(in: CharacterSet(charactersIn: "\r"))

            if trimmed.isEmpty { continue }

            // Doc comments
            if trimmed.hasPrefix("## ") {
                pendingDocComments.append(DocComment(text: String(trimmed.dropFirst(3))))
                continue
            }
            if trimmed.hasPrefix("##") {
                pendingDocComments.append(DocComment(text: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                continue
            }
            // Regular comments
            if trimmed.hasPrefix("#") { continue }

            // @parallel block opener
            if trimmed.hasPrefix("@parallel ") {
                if inParallel { finalizeParallel() }
                currentParallelName = String(trimmed.dropFirst("@parallel ".count))
                    .trimmingCharacters(in: .whitespaces)
                currentParallelDocs = pendingDocComments
                pendingDocComments.removeAll()
                inParallel = true
                section = .preamble
                continue
            }

            // region header inside @parallel
            if inParallel && trimmed.hasPrefix("region ") {
                finalizeRegion()
                currentRegionName = String(trimmed.dropFirst("region ".count))
                    .trimmingCharacters(in: .whitespaces)
                pendingDocComments.removeAll()
                continue
            }

            // Section headers
            if trimmed == "@states" || trimmed.hasPrefix("@states ") {
                if inParallel && indent > 0 {
                    section = .parallelStates
                } else {
                    if inParallel { finalizeParallel() }
                    section = .states
                }
                pendingDocComments.removeAll()
                continue
            }
            if trimmed == "@transitions" || trimmed.hasPrefix("@transitions ") {
                if inCompound { finalizeCompound() }
                if inParallel && indent > 0 {
                    section = .parallelTransitions
                } else {
                    if inParallel { finalizeParallel() }
                    section = .transitions
                }
                pendingDocComments.removeAll()
                continue
            }
            if trimmed == "@invariants" {
                if inParallel { finalizeParallel() }
                section = .invariants
                continue
            }

            // @import
            if trimmed.hasPrefix("@import ") {
                let rest = String(trimmed.dropFirst("@import ".count))
                var s = rest[...]
                let decl = try ImportDeclParser(lineNum: lineNum).parse(&s)
                imports.append(decl)
                pendingDocComments.removeAll()
                continue
            }

            // @entry / @exit hooks
            if trimmed.hasPrefix("@entry") || trimmed.hasPrefix("@exit") {
                if inParallel { finalizeParallel() }
                var s = trimmed[...]
                let hook = try EntryExitDeclParser(lineNum: lineNum).parse(&s)
                entryExitHooks.append(hook)
                pendingDocComments.removeAll()
                continue
            }

            // @on reactive transition
            if trimmed.hasPrefix("@on ") {
                if inParallel { finalizeParallel() }
                section = .transitions
                let docs = pendingDocComments
                pendingDocComments.removeAll()
                var s = trimmed[...]
                if let rs = try ReactiveStmtParser(lineNum: lineNum).parse(&s) {
                    transitions.append(.reactive(ReactiveStmt(
                        source: rs.source,
                        ownState: rs.ownState,
                        arrow: rs.arrow,
                        destination: rs.destination,
                        action: rs.action,
                        docComments: docs
                    )))
                }
                continue
            }

            // Silently ignore v1-only directives
            if trimmed.hasPrefix("@compose ") || trimmed.hasPrefix("@factory") ||
               trimmed.hasPrefix("@continuation") || trimmed.hasPrefix("@history") {
                pendingDocComments.removeAll()
                continue
            }

            switch section {
            case .preamble:
                if trimmed.hasPrefix("machine") {
                    if inParallel { finalizeParallel() }
                    let afterMachine = String(trimmed.dropFirst("machine".count))
                    var s = afterMachine[...]
                    let result = try MachineDeclParser(fallback: machineNameFallback).parse(&s)
                    machineName = result.name
                    contextType = result.contextType
                    machineDocComments = pendingDocComments
                    pendingDocComments.removeAll()
                }

            case .states:
                let docs = pendingDocComments
                pendingDocComments.removeAll()

                // Close compound block on "}"
                if trimmed == "}" {
                    if inCompound { finalizeCompound() }
                    continue
                }

                // Inside compound block: route children and inner transitions
                if inCompound {
                    var s = trimmed[...]
                    if let simpleDecl = try SimpleStateDeclParser(lineNum: lineNum).parse(&s) {
                        currentCompoundChildren.append(simpleDecl)
                    } else {
                        var t = trimmed[...]
                        if let stmt = try TransitionStmtParser(lineNum: lineNum).parse(&t) {
                            currentCompoundTransitions.append(stmt)
                        }
                    }
                    continue
                }

                // Detect compound opener: "state Name [@history] {"
                if (trimmed.hasPrefix("state ") || trimmed.hasPrefix("state(")) && trimmed.hasSuffix("{") {
                    var inner = String(trimmed.dropFirst("state".count)).dropLast()
                        .trimmingCharacters(in: .whitespaces)
                    var hist: HistoryModifier? = nil
                    if inner.hasSuffix("@history(deep)") {
                        hist = .deep
                        inner = String(inner.dropLast("@history(deep)".count)).trimmingCharacters(in: .whitespaces)
                    } else if inner.hasSuffix("@history") {
                        hist = .shallow
                        inner = String(inner.dropLast("@history".count)).trimmingCharacters(in: .whitespaces)
                    }
                    currentCompoundName = inner
                    currentCompoundHistory = hist
                    currentCompoundDocs = docs
                    inCompound = true
                    continue
                }

                var s = trimmed[...]
                if let simpleDecl = try SimpleStateDeclParser(lineNum: lineNum).parse(&s) {
                    states.append(.simple(SimpleStateDecl(
                        kind: simpleDecl.kind,
                        params: simpleDecl.params,
                        name: simpleDecl.name,
                        history: simpleDecl.history,
                        docComments: docs
                    )))
                }

            case .transitions:
                let docs = pendingDocComments
                pendingDocComments.removeAll()

                if let decl = try parseTransitionDecl(trimmed: trimmed, lineNum: lineNum, docs: docs) {
                    transitions.append(decl)
                }

            case .parallelStates:
                let docs = pendingDocComments
                pendingDocComments.removeAll()
                var s = trimmed[...]
                if let simpleDecl = try SimpleStateDeclParser(lineNum: lineNum).parse(&s) {
                    currentRegionStates.append(.simple(SimpleStateDecl(
                        kind: simpleDecl.kind,
                        params: simpleDecl.params,
                        name: simpleDecl.name,
                        history: simpleDecl.history,
                        docComments: docs
                    )))
                }

            case .parallelTransitions:
                let docs = pendingDocComments
                pendingDocComments.removeAll()
                var s = trimmed[...]
                if let stmt = try TransitionStmtParser(lineNum: lineNum).parse(&s) {
                    currentRegionTransitions.append(TransitionStmt(
                        source: stmt.source,
                        arrow: stmt.arrow,
                        event: stmt.event,
                        guard: stmt.guard,
                        destination: stmt.destination,
                        fork: stmt.fork,
                        action: stmt.action,
                        docComments: docs
                    ))
                }

            case .invariants:
                pendingDocComments.removeAll()
            }
        }

        if inParallel { finalizeParallel() }

        return UrkelFile(
            machineName: machineName,
            contextType: contextType,
            docComments: machineDocComments,
            imports: imports,
            parallels: parallels,
            states: states,
            entryExitHooks: entryExitHooks,
            transitions: transitions
        )
    }

    // MARK: - Helpers

    private func consumeLine(_ input: inout Substring) -> Substring {
        if let nlIdx = input.firstIndex(of: "\n") {
            let line = input[..<nlIdx]
            input = input[input.index(after: nlIdx)...]
            return line
        }
        let line = input
        input = input[input.endIndex...]
        return line
    }

    private func parseTransitionDecl(trimmed: String, lineNum: Int, docs: [DocComment]) throws -> TransitionDecl? {
        if trimmed.hasPrefix("@on ") {
            var s = trimmed[...]
            if let rs = try ReactiveStmtParser(lineNum: lineNum).parse(&s) {
                return .reactive(ReactiveStmt(
                    source: rs.source,
                    ownState: rs.ownState,
                    arrow: rs.arrow,
                    destination: rs.destination,
                    action: rs.action,
                    docComments: docs
                ))
            }
            return nil
        }

        var s = trimmed[...]
        if let stmt = try TransitionStmtParser(lineNum: lineNum).parse(&s) {
            return .transition(TransitionStmt(
                source: stmt.source,
                arrow: stmt.arrow,
                event: stmt.event,
                guard: stmt.guard,
                destination: stmt.destination,
                fork: stmt.fork,
                action: stmt.action,
                docComments: docs
            ))
        }
        return nil
    }
}

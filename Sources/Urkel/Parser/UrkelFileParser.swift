import Foundation

// MARK: - Parse Error

/// Parse error produced by the v2 Urkel parser.
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

/// The v2 Urkel parser — produces a `UrkelFile` from `.urkel` source text.
public struct UrkelParser {
    public init() {}

    /// Parse `.urkel` source text into a `UrkelFile` AST.
    public static func parse(_ source: String) throws -> UrkelFile {
        try UrkelParser().parse(source: source, machineNameFallback: nil)
    }

    /// Instance parse method — for compatibility with generator.
    public func parse(source: String, machineNameFallback: String? = nil) throws -> UrkelFile {
        var impl = LineOrientedParser(source: source, machineNameFallback: machineNameFallback)
        return try impl.parse()
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
            return indent + printSimpleState(s)
        case .compound(let c):
            var ls = ["\(indent)state \(c.name) {"]
            for child in c.children { ls.append("\(indent)  \(printSimpleState(child))") }
            ls.append("\(indent)}")
            return ls.joined(separator: "\n")
        }
    }

    private func printSimpleState(_ s: SimpleStateDecl) -> String {
        if s.params.isEmpty { return "\(s.kind.rawValue) \(s.name)" }
        let ps = s.params.map { "\($0.label): \($0.typeExpr)" }.joined(separator: ", ")
        switch s.kind {
        case .state:         return "state \(s.name)(\(ps))"
        case .`init`, .final: return "\(s.kind.rawValue)(\(ps)) \(s.name)"
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

// MARK: - Line-Oriented Parser Implementation

private struct LineOrientedParser {
    let lines: [String]
    let machineNameFallback: String?

    init(source: String, machineNameFallback: String?) {
        self.lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
        self.machineNameFallback = machineNameFallback
    }

    private enum Section {
        case preamble, states, transitions, invariants
        case parallelStates, parallelTransitions
    }

    mutating func parse() throws -> UrkelFile {
        var machineName = machineNameFallback ?? "Machine"
        var contextType: String?
        var pendingDocComments: [DocComment] = []
        var imports: [ImportDecl] = []
        var states: [StateDecl] = []
        var transitions: [TransitionDecl] = []
        var entryExitHooks: [EntryExitDecl] = []
        var section: Section = .preamble
        var machineDocComments: [DocComment] = []

        // Compound state block tracking
        var inCompound = false
        var currentCompoundName = ""
        var currentCompoundHistory: HistoryModifier? = nil
        var currentCompoundDocs: [DocComment] = []
        var currentCompoundChildren: [SimpleStateDecl] = []
        var currentCompoundTransitions: [TransitionStmt] = []

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

        // Parallel tracking
        var parallels: [ParallelDecl] = []
        var inParallel = false
        var currentParallelName = ""
        var currentParallelDocs: [DocComment] = []
        var currentParallelRegions: [RegionDecl] = []
        var currentRegionName = ""
        var currentRegionStates: [StateDecl] = []
        var currentRegionTransitions: [TransitionStmt] = []

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

        for (idx, rawLine) in lines.enumerated() {
            let lineNum = idx + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let indent = rawLine.prefix(while: { $0 == " " }).count

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

            // Section headers — route based on indentation
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

            // @import (can appear in preamble or before states block)
            if trimmed.hasPrefix("@import ") {
                let rest = String(trimmed.dropFirst("@import ".count)).trimmingCharacters(in: .whitespaces)
                imports.append(try parseImport(rest, line: lineNum))
                pendingDocComments.removeAll()
                continue
            }

            // @entry / @exit hooks
            if trimmed.hasPrefix("@entry ") || trimmed.hasPrefix("@exit ") {
                if inParallel { finalizeParallel() }
                entryExitHooks.append(try parseEntryExit(trimmed, line: lineNum))
                pendingDocComments.removeAll()
                continue
            }

            // @on reactive transition — always at outer level; close parallel first
            if trimmed.hasPrefix("@on ") {
                if inParallel { finalizeParallel() }
                section = .transitions
                let docs = pendingDocComments
                pendingDocComments.removeAll()
                if let decl = try parseTransitionDecl(trimmed, line: lineNum, docComments: docs) {
                    transitions.append(decl)
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
                    let rest = String(trimmed.dropFirst("machine".count)).trimmingCharacters(in: .whitespaces)
                    (machineName, contextType) = parseMachineDecl(rest, fallback: machineNameFallback)
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
                    if let childDecl = try parseStateDecl(trimmed, line: lineNum, docComments: docs),
                       case .simple(let s) = childDecl {
                        currentCompoundChildren.append(s)
                    } else if let transDecl = try parseTransitionDecl(trimmed, line: lineNum, docComments: docs),
                              case .transition(let t) = transDecl {
                        currentCompoundTransitions.append(t)
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

                if let decl = try parseStateDecl(trimmed, line: lineNum, docComments: docs) {
                    states.append(decl)
                }
            case .transitions:
                let docs = pendingDocComments
                pendingDocComments.removeAll()
                if let decl = try parseTransitionDecl(trimmed, line: lineNum, docComments: docs) {
                    transitions.append(decl)
                }
            case .parallelStates:
                let docs = pendingDocComments
                pendingDocComments.removeAll()
                if let decl = try parseStateDecl(trimmed, line: lineNum, docComments: docs) {
                    currentRegionStates.append(decl)
                }
            case .parallelTransitions:
                let docs = pendingDocComments
                pendingDocComments.removeAll()
                if let decl = try parseTransitionDecl(trimmed, line: lineNum, docComments: docs) {
                    if case .transition(let t) = decl {
                        currentRegionTransitions.append(t)
                    }
                }
            case .invariants:
                pendingDocComments.removeAll()
            }
        }

        // Close any open parallel block
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

    // MARK: - Preamble

    func parseMachineDecl(_ rest: String, fallback: String?) -> (String, String?) {
        if rest.isEmpty { return (fallback ?? "Machine", nil) }
        // "Name" or "Name: Context"
        if let colonIdx = rest.firstIndex(of: ":") {
            let name = String(rest[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let ctx  = String(rest[rest.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            return (name.isEmpty ? (fallback ?? "Machine") : name, ctx.isEmpty ? nil : ctx)
        }
        let name = rest.trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? (fallback ?? "Machine") : name, nil)
    }

    func parseImport(_ rest: String, line: Int) throws -> ImportDecl {
        let parts = rest.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let name = parts.first, !name.isEmpty else {
            throw UrkelParseError(message: "Expected import name", line: line)
        }
        var from: String? = nil
        if parts.count >= 3 && parts[1] == "from" { from = parts[2] }
        return ImportDecl(name: name, from: from)
    }

    func parseEntryExit(_ trimmed: String, line: Int) throws -> EntryExitDecl {
        let isEntry = trimmed.hasPrefix("@entry")
        let dropCount = isEntry ? "@entry ".count : "@exit ".count
        let rest = String(trimmed.dropFirst(dropCount)).trimmingCharacters(in: .whitespaces)
        let slashParts = rest.components(separatedBy: "/")
        guard slashParts.count >= 2 else {
            throw UrkelParseError(message: "Expected '/' in @\(isEntry ? "entry" : "exit") hook", line: line)
        }
        let stateName = slashParts[0].trimmingCharacters(in: .whitespaces)
        let actionStr = slashParts[1...].joined(separator: "/").trimmingCharacters(in: .whitespaces)
        let actions   = actionStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return EntryExitDecl(
            hook: isEntry ? .entry : .exit,
            state: StateRef(stateName.components(separatedBy: ".")),
            actions: actions
        )
    }

    // MARK: - States

    func parseStateDecl(_ trimmed: String, line: Int, docComments: [DocComment]) throws -> StateDecl? {
        if trimmed.hasPrefix("init") && (trimmed.count == 4 || !trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)].isLetter) {
            return try parseInitOrFinalState(trimmed, kind: .`init`, line: line, docComments: docComments)
        }
        if trimmed.hasPrefix("final") && (trimmed.count == 5 || !trimmed[trimmed.index(trimmed.startIndex, offsetBy: 5)].isLetter) {
            return try parseInitOrFinalState(trimmed, kind: .final, line: line, docComments: docComments)
        }
        if trimmed.hasPrefix("state ") || trimmed == "state" || trimmed.hasPrefix("state(") {
            return try parseRegularOrCompoundState(trimmed, line: line, docComments: docComments)
        }
        return nil
    }

    func parseInitOrFinalState(_ trimmed: String, kind: StateKind, line: Int, docComments: [DocComment]) throws -> StateDecl {
        let keyword = kind.rawValue
        var rest = String(trimmed.dropFirst(keyword.count)).trimmingCharacters(in: .whitespaces)

        var params: [Parameter] = []
        if rest.hasPrefix("(") {
            let (p, after) = try parseParamList(rest, line: line)
            params = p
            rest = after.trimmingCharacters(in: .whitespaces)
        }

        let parts = rest.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let name = parts.first, !name.isEmpty else {
            throw UrkelParseError(message: "Expected state name after '\(keyword)'", line: line)
        }

        var history: HistoryModifier? = nil
        if rest.contains("@history") { history = rest.contains("(deep)") ? .deep : .shallow }

        return .simple(SimpleStateDecl(kind: kind, params: params, name: name, history: history, docComments: docComments))
    }

    func parseRegularOrCompoundState(_ trimmed: String, line: Int, docComments: [DocComment]) throws -> StateDecl {
        var rest = String(trimmed.dropFirst("state".count)).trimmingCharacters(in: .whitespaces)

        // Compound: "state Name {"
        if rest.hasSuffix("{") {
            let name = String(rest.dropLast()).trimmingCharacters(in: .whitespaces)
            return .compound(CompoundStateDecl(name: name, docComments: docComments))
        }

        // Support both orderings:
        //   state(params) Name   — consistent with init/final syntax
        //   state Name (params)  — alternative ordering
        var params: [Parameter] = []
        if rest.hasPrefix("(") {
            // state(params) Name
            let (p, after) = try parseParamList(rest, line: line)
            params = p
            rest = after.trimmingCharacters(in: .whitespaces)
        }

        // Parse name
        let nameEnd = rest.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" }) ?? rest.endIndex
        let name = String(rest[..<nameEnd])
        guard !name.isEmpty else {
            throw UrkelParseError(message: "Expected state name after 'state'", line: line)
        }
        rest = String(rest[nameEnd...]).trimmingCharacters(in: .whitespaces)

        // state Name (params) — trailing params (alternative syntax)
        if params.isEmpty && rest.hasPrefix("(") {
            let (p, after) = try parseParamList(rest, line: line)
            params = p
            rest = after.trimmingCharacters(in: .whitespaces)
        }

        var history: HistoryModifier? = nil
        if rest.hasPrefix("@history") { history = rest.contains("(deep)") ? .deep : .shallow }

        return .simple(SimpleStateDecl(kind: .state, params: params, name: name, history: history, docComments: docComments))
    }

    // MARK: - Transitions

    func parseTransitionDecl(_ trimmed: String, line: Int, docComments: [DocComment]) throws -> TransitionDecl? {
        if trimmed.hasPrefix("@on ") {
            return try parseReactiveStmt(trimmed, line: line, docComments: docComments)
        }

        // Parse source (state name or *)
        let source: TransitionSource
        var rest: String

        if trimmed.hasPrefix("*") {
            source = .wildcard
            rest = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else {
            let i = trimmed.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" && c != "." }) ?? trimmed.endIndex
            let stateName = String(trimmed[..<i])
            guard !stateName.isEmpty else { return nil }
            source = .state(StateRef(stateName.components(separatedBy: ".")))
            rest = String(trimmed[i...]).trimmingCharacters(in: .whitespaces)
        }

        // Parse first arrow
        let arrow: Arrow
        if rest.hasPrefix("-*>") {
            arrow = .internal
            rest = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if rest.hasPrefix("->") {
            arrow = .standard
            rest = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }

        guard !rest.isEmpty else {
            throw UrkelParseError(
                message: "Transition must follow: Source -> event -> Dest",
                line: line
            )
        }

        // Parse event / timer / always
        let event: EventOrTimer
        if rest.hasPrefix("after(") || rest.hasPrefix("after (") {
            let (e, after) = try parseTimer(rest, line: line)
            event = e
            rest = after.trimmingCharacters(in: .whitespaces)
        } else if rest.hasPrefix("always") {
            let idx6 = rest.index(rest.startIndex, offsetBy: min(6, rest.count))
            let nextChar = idx6 < rest.endIndex ? rest[idx6] : " "
            if nextChar.isWhitespace || idx6 == rest.endIndex || nextChar == "[" || nextChar == "/" {
                event = .always
                rest = String(rest.dropFirst("always".count)).trimmingCharacters(in: .whitespaces)
            } else {
                let (e, after) = try parseEvent(rest, line: line)
                event = e
                rest = after.trimmingCharacters(in: .whitespaces)
            }
        } else {
            let (e, after) = try parseEvent(rest, line: line)
            event = e
            rest = after.trimmingCharacters(in: .whitespaces)
        }

        // Optional guard [guardName] | [!guardName] | [else]
        var guardClause: GuardClause? = nil
        if rest.hasPrefix("[") {
            let (g, after) = try parseGuardClause(rest, line: line)
            guardClause = g
            rest = after.trimmingCharacters(in: .whitespaces)
        }

        // Optional -> Dest [=> Machine.init]
        var destination: StateRef? = nil
        var forkClause: ForkClause? = nil
        if rest.hasPrefix("->") {
            rest = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let i = rest.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" && c != "." }) ?? rest.endIndex
            let destName = String(rest[..<i])
            if !destName.isEmpty {
                destination = StateRef(destName.components(separatedBy: "."))
                rest = String(rest[i...]).trimmingCharacters(in: .whitespaces)
            }
            if rest.hasPrefix("=>") {
                let (f, after) = try parseForkClause(rest, line: line)
                forkClause = f
                rest = after.trimmingCharacters(in: .whitespaces)
            }
        }

        // Optional / action1, action2
        var actionClause: ActionClause? = nil
        if rest.hasPrefix("/") {
            let actionStr = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
            let actions = actionStr.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !actions.isEmpty { actionClause = ActionClause(actions: actions) }
        }

        return .transition(TransitionStmt(
            source: source,
            arrow: arrow,
            event: event,
            guard: guardClause,
            destination: destination,
            fork: forkClause,
            action: actionClause,
            docComments: docComments
        ))
    }

    func parseReactiveStmt(_ trimmed: String, line: Int, docComments: [DocComment]) throws -> TransitionDecl {
        var rest = String(trimmed.dropFirst("@on ".count)).trimmingCharacters(in: .whitespaces)

        guard let colonColonRange = rest.range(of: "::") else {
            throw UrkelParseError(message: "Expected '::' in @on source", line: line)
        }
        let targetStr = String(rest[..<colonColonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        rest = String(rest[colonColonRange.upperBound...])

        let reactiveTarget: ReactiveTarget
        if targetStr.contains(".") {
            let parts = targetStr.components(separatedBy: ".")
            reactiveTarget = .region(parallel: parts[0], region: parts[1])
        } else {
            reactiveTarget = .machine(targetStr)
        }

        let i = rest.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" && c != "*" }) ?? rest.endIndex
        let stateStr = String(rest[..<i])
        rest = String(rest[i...]).trimmingCharacters(in: .whitespaces)

        let reactiveState: ReactiveState
        switch stateStr {
        case "init":  reactiveState = .`init`
        case "final": reactiveState = .final
        case "*":     reactiveState = .any
        default:      reactiveState = .named(stateStr)
        }

        var ownState: String? = nil
        if rest.hasPrefix(",") {
            rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
            let j = rest.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" }) ?? rest.endIndex
            ownState = String(rest[..<j])
            rest = String(rest[j...]).trimmingCharacters(in: .whitespaces)
        }

        let arrow: Arrow
        if rest.hasPrefix("-*>") {
            arrow = .internal
            rest = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if rest.hasPrefix("->") {
            arrow = .standard
            rest = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        } else {
            throw UrkelParseError(message: "Expected '->' in @on statement", line: line)
        }

        var destination: StateRef? = nil
        let j = rest.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" && c != "." }) ?? rest.endIndex
        let destName = String(rest[..<j])
        if !destName.isEmpty {
            destination = StateRef(destName.components(separatedBy: "."))
            rest = String(rest[j...]).trimmingCharacters(in: .whitespaces)
        }

        var actionClause: ActionClause? = nil
        if rest.hasPrefix("/") {
            let actionStr = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
            let actions = actionStr.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !actions.isEmpty { actionClause = ActionClause(actions: actions) }
        }

        return .reactive(ReactiveStmt(
            source: ReactiveSource(target: reactiveTarget, state: reactiveState),
            ownState: ownState,
            arrow: arrow,
            destination: destination,
            action: actionClause,
            docComments: docComments
        ))
    }

    // MARK: - Sub-parsers

    func parseParamList(_ s: String, line: Int) throws -> ([Parameter], String) {
        guard s.hasPrefix("(") else { return ([], s) }
        var params: [Parameter] = []
        var i = s.index(after: s.startIndex)
        var depth = 1
        var current = ""

        while i < s.endIndex && depth > 0 {
            let c = s[i]
            switch c {
            case "(", "<", "[", "{": depth += 1
            case ")", ">", "]", "}":
                depth -= 1
                if depth == 0 {
                    let t = current.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { params.append(try parseParam(t, line: line)) }
                    return (params, String(s[s.index(after: i)...]))
                }
            case "," where depth == 1:
                let t = current.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { params.append(try parseParam(t, line: line)) }
                current = ""
                i = s.index(after: i)
                continue
            default: break
            }
            current.append(c)
            i = s.index(after: i)
        }
        throw UrkelParseError(message: "Unbalanced parentheses in parameter list", line: line)
    }

    func parseParam(_ s: String, line: Int) throws -> Parameter {
        var depth = 0
        var colonIdx: String.Index? = nil
        var idx = s.startIndex
        while idx < s.endIndex {
            switch s[idx] {
            case "<", "[", "(", "{": depth += 1
            case ">", "]", ")", "}": depth -= 1
            case ":" where depth == 0: colonIdx = idx
            default: break
            }
            if colonIdx != nil { break }
            idx = s.index(after: idx)
        }
        guard let ci = colonIdx else {
            throw UrkelParseError(message: "Expected ':' in parameter '\(s)'", line: line)
        }
        let label    = String(s[..<ci]).trimmingCharacters(in: .whitespaces)
        let typeExpr = String(s[s.index(after: ci)...]).trimmingCharacters(in: .whitespaces)
        return Parameter(label: label, typeExpr: typeExpr)
    }

    func parseEvent(_ s: String, line: Int) throws -> (EventOrTimer, String) {
        let i = s.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" }) ?? s.endIndex
        let name = String(s[..<i])
        guard !name.isEmpty else {
            throw UrkelParseError(message: "Expected event name", line: line)
        }
        var rest = String(s[i...]).trimmingCharacters(in: .whitespaces)
        var params: [Parameter] = []
        if rest.hasPrefix("(") {
            let (p, after) = try parseParamList(rest, line: line)
            params = p
            rest = after.trimmingCharacters(in: .whitespaces)
        }
        return (.event(EventDecl(name: name, params: params)), rest)
    }

    func parseTimer(_ s: String, line: Int) throws -> (EventOrTimer, String) {
        // after(30s) or after(500ms) or after(1min)
        guard s.hasPrefix("after") else { throw UrkelParseError(message: "Expected 'after'", line: line) }
        var rest = String(s.dropFirst("after".count)).trimmingCharacters(in: .whitespaces)
        guard rest.hasPrefix("(") else { throw UrkelParseError(message: "Expected '(' after 'after'", line: line) }

        var depth = 0
        var contentStart: String.Index? = nil
        var contentEnd: String.Index? = nil
        var afterIdx: String.Index = rest.startIndex
        for idx in rest.indices {
            let c = rest[idx]
            if c == "(" {
                depth += 1
                if depth == 1 { contentStart = rest.index(after: idx) }
            } else if c == ")" {
                depth -= 1
                if depth == 0 { contentEnd = idx; afterIdx = rest.index(after: idx); break }
            }
        }
        guard let cs = contentStart, let ce = contentEnd else {
            throw UrkelParseError(message: "Unbalanced '(' in after()", line: line)
        }
        let content = String(rest[cs..<ce]).trimmingCharacters(in: .whitespaces)
        let duration = parseDurationLiteral(content) ?? Duration(value: 1, unit: .s)
        return (.timer(TimerDecl(duration: duration)), String(rest[afterIdx...]).trimmingCharacters(in: .whitespaces))
    }

    func parseDurationLiteral(_ s: String) -> Duration? {
        if s.hasSuffix("min"), let v = Double(s.dropLast(3)) { return Duration(value: v, unit: .min) }
        if s.hasSuffix("ms"),  let v = Double(s.dropLast(2)) { return Duration(value: v, unit: .ms) }
        if s.hasSuffix("s"),   let v = Double(s.dropLast(1)) { return Duration(value: v, unit: .s) }
        return nil
    }

    func parseGuardClause(_ s: String, line: Int) throws -> (GuardClause, String) {
        guard s.hasPrefix("[") else { throw UrkelParseError(message: "Expected '[' for guard", line: line) }
        guard let endIdx = s.firstIndex(of: "]") else {
            throw UrkelParseError(message: "Expected ']' to close guard", line: line)
        }
        let content = String(s[s.index(after: s.startIndex)..<endIdx]).trimmingCharacters(in: .whitespaces)
        let rest = String(s[s.index(after: endIdx)...])
        let g: GuardClause
        if content == "else" {
            g = .else
        } else if content.hasPrefix("!") {
            g = .negated(String(content.dropFirst()))
        } else {
            g = .named(content)
        }
        return (g, rest)
    }

    func parseForkClause(_ s: String, line: Int) throws -> (ForkClause, String) {
        var rest = String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces) // drop "=>"
        let i = rest.firstIndex(where: { c in !c.isLetter && !c.isNumber && c != "_" && c != "." }) ?? rest.endIndex
        let ref = String(rest[..<i])  // e.g. "MachineName.init"
        rest = String(rest[i...]).trimmingCharacters(in: .whitespaces)
        let machineName = ref.components(separatedBy: ".").first ?? ref
        var bindings: [ForkBinding] = []
        if rest.hasPrefix("(") {
            let (params, after) = try parseParamList(rest, line: line)
            bindings = params.map { ForkBinding(param: $0.label, source: $0.typeExpr) }
            rest = after.trimmingCharacters(in: .whitespaces)
        }
        return (ForkClause(machine: machineName, bindings: bindings), rest)
    }
}

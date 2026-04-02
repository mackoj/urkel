import UrkelAST

/// Mustache template context model for v2 `UrkelFile`.
///
/// Mirrors the shape expected by `swift.mustache` and any user-supplied
/// templates. All keys are stable — adding fields is backward-compatible.
public extension UrkelFile {
    var templateContext: [String: Any] {
        let machineTN = typeName(from: machineName)
        let hasContext = contextType != nil

        let stateRows: [[String: Any]] = simpleStates.enumerated().map { idx, state in
            [
                "name":         state.name,
                "typeName":     typeName(from: state.name),
                "variableName": variableName(from: typeName(from: state.name)),
                "kind":         state.kind.rawValue,
                "isInitial":    state.kind == .`init`,
                "isTerminal":   state.kind == .final,
                "hasParams":    !state.params.isEmpty,
                "params":       state.params.enumerated().map { pIdx, p in
                    ["name": p.label, "type": p.typeExpr, "isLast": pIdx == state.params.count - 1] as [String: Any]
                },
                "isLast":       idx == simpleStates.count - 1
            ] as [String: Any]
        }

        let transitionRows: [[String: Any]] = transitionStmts.enumerated().map { idx, t in
            let event: String
            let params: [Parameter]
            let isTimer: Bool
            switch t.event {
            case .event(let ev):
                event  = ev.name
                params = ev.params.map { Parameter(label: $0.label, typeExpr: $0.typeExpr) }
                isTimer = false
            case .timer:
                event  = "after"
                params = []
                isTimer = true
            case .always:
                event  = "always"
                params = []
                isTimer = false
            }
            let guardRows: [[String: Any]] = {
                guard let g = t.`guard` else { return [] }
                switch g {
                case .named(let n):   return [["name": n, "negated": false, "isElse": false]]
                case .negated(let n): return [["name": n, "negated": true,  "isElse": false]]
                case .else:           return [["name": "else", "negated": false, "isElse": true]]
                }
            }()
            return [
                "from":           sourceName(of: t),
                "fromTypeName":   typeName(from: sourceName(of: t)),
                "event":          event,
                "eventTypeName":  typeName(from: event),
                "to":             t.destination?.name as Any,
                "toTypeName":     t.destination.map { typeName(from: $0.name) } as Any,
                "params":         params.enumerated().map { pIdx, p in
                    ["name": p.label, "type": p.typeExpr, "isLast": pIdx == params.count - 1] as [String: Any]
                },
                "guards":         guardRows,
                "hasGuards":      !guardRows.isEmpty,
                "actions":        t.action?.actions as Any,
                "hasActions":     t.action != nil,
                "isInternal":     t.arrow == .`internal`,
                "isOutputEvent":  t.isOutputEvent,
                "spawnedMachine": t.fork?.machine as Any,
                "isTimer":        isTimer,
                "isLast":         idx == transitionStmts.count - 1
            ] as [String: Any]
        }

        let allActionNames: [String] = {
            var seen = Set<String>()
            var result: [String] = []
            for t in transitionStmts {
                for a in (t.action?.actions ?? []) where seen.insert(a).inserted { result.append(a) }
            }
            for h in entryExitHooks {
                for a in h.actions where seen.insert(a).inserted { result.append(a) }
            }
            return result
        }()

        let allGuardNames: [String] = {
            var seen = Set<String>()
            var result: [String] = []
            for t in transitionStmts {
                if let g = t.guard {
                    switch g {
                    case .named(let n), .negated(let n):
                        if seen.insert(n).inserted { result.append(n) }
                    case .else: break
                    }
                }
            }
            return result
        }()

        let outputEvents: [[String: Any]] = transitionStmts
            .filter(\.isOutputEvent)
            .compactMap { t -> [String: Any]? in
                guard case .event(let ev) = t.event else { return nil }
                return [
                    "event":     ev.name,
                    "eventType": typeName(from: ev.name),
                    "params":    ev.params.map { ["name": $0.label, "type": $0.typeExpr] as [String: Any] },
                    "from":      sourceName(of: t)
                ]
            }

        // groupedTransitions: group transitionRows by source state for templates
        let groupedTransitions: [[String: Any]] = {
            var groups: [(source: String, rows: [[String: Any]])] = []
            for row in transitionRows {
                guard let src = row["fromTypeName"] as? String else { continue }
                if let idx = groups.firstIndex(where: { $0.source == src }) {
                    groups[idx].rows.append(row)
                } else {
                    groups.append((source: src, rows: [row]))
                }
            }
            return groups.map { g -> [String: Any] in
                var rows = g.rows
                // mark isLast on the inner list
                for i in rows.indices { rows[i]["isLast"] = i == rows.count - 1 }
                return ["sourceStateTypeName": g.source, "transitions": rows] as [String: Any]
            }
        }()

        return [
            "machineName":         machineName,
            "machineTypeName":     machineTN,
            "machineVariableName": variableName(from: machineTN),
            "contextType":         contextType as Any,
            "hasContext":          hasContext,
            "imports":             imports.map { ["name": $0.name, "from": $0.from as Any] as [String: Any] },
            "initParams":          (initState?.params ?? []).enumerated().map { idx, p in
                ["name": p.label, "type": p.typeExpr, "isLast": idx == (initState?.params.count ?? 0) - 1] as [String: Any]
            },
            "states":              stateRows,
            "transitions":         transitionRows,
            "groupedTransitions":  groupedTransitions,
            "actions":             allActionNames,
            "guards":              allGuardNames,
            "outputEvents":        outputEvents,
            "composedMachines":    imports.enumerated().map { idx, imp in
                ["name": imp.name, "typeName": typeName(from: imp.name), "isLast": idx == imports.count - 1] as [String: Any]
            },
            "initialState":        initState?.name as Any,
            "initialStateTypeName": initState.map { typeName(from: $0.name) } ?? "",
        ]
    }

    private func sourceName(of t: TransitionStmt) -> String {
        switch t.source {
        case .state(let ref): return ref.name
        case .wildcard:       return "*"
        }
    }
}

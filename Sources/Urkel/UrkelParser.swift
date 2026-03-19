import Foundation

public struct UrkelParseError: Error, Equatable, CustomStringConvertible, LocalizedError, Sendable {
    public let line: Int
    public let column: Int
    public let message: String

    public init(line: Int, column: Int, message: String) {
        self.line = line
        self.column = column
        self.message = message
    }

    public var description: String {
        "Parse error at line \(line), column \(column): \(message)"
    }

    public var errorDescription: String? { description }
}

public struct UrkelParser {
    public init() {}

    public func parse(source: String, machineNameFallback: String? = nil) throws -> MachineAST {
        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var index = 0
        var imports: [String] = []
        var machineName = machineNameFallback ?? "Machine"
        var contextType: String?
        var factory: MachineAST.Factory?
        var states: [MachineAST.StateNode] = []
        var transitions: [MachineAST.TransitionNode] = []
        let sourceLineCount = max(lines.count, 1)

        func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespaces)
        }

        func isTrivia(_ value: String) -> Bool {
            let t = trimmed(value)
            return t.isEmpty || t.hasPrefix("#")
        }

        func isIdentifier(_ value: String) -> Bool {
            let pattern = "^[A-Za-z][A-Za-z0-9_]*$"
            return value.range(of: pattern, options: .regularExpression) != nil
        }

        func splitTopLevelCommas(_ raw: String, line: Int, baseColumn: Int) throws -> [(text: String, startColumn: Int)] {
            var result: [String] = []
            var columns: [Int] = []
            var current = ""
            var parenDepth = 0
            var angleDepth = 0
            var bracketDepth = 0
            var braceDepth = 0
            var tokenStartColumn = baseColumn
            var absoluteColumn = baseColumn

            for scalar in raw.unicodeScalars {
                let c = Character(scalar)
                switch c {
                case "(": parenDepth += 1
                case ")":
                    parenDepth -= 1
                    if parenDepth < 0 {
                        throw UrkelParseError(line: line, column: absoluteColumn, message: "Unbalanced closing ')' in parameter list")
                    }
                case "<": angleDepth += 1
                case ">":
                    angleDepth -= 1
                    if angleDepth < 0 {
                        throw UrkelParseError(line: line, column: absoluteColumn, message: "Unbalanced closing '>' in parameter list")
                    }
                case "[": bracketDepth += 1
                case "]":
                    bracketDepth -= 1
                    if bracketDepth < 0 {
                        throw UrkelParseError(line: line, column: absoluteColumn, message: "Unbalanced closing ']' in parameter list")
                    }
                case "{": braceDepth += 1
                case "}":
                    braceDepth -= 1
                    if braceDepth < 0 {
                        throw UrkelParseError(line: line, column: absoluteColumn, message: "Unbalanced closing '}' in parameter list")
                    }
                case "," where parenDepth == 0 && angleDepth == 0 && bracketDepth == 0 && braceDepth == 0:
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        let leadingWhitespace = current.prefix { $0.isWhitespace }.count
                        result.append(trimmed)
                        columns.append(tokenStartColumn + leadingWhitespace)
                    }
                    current.removeAll(keepingCapacity: true)
                    tokenStartColumn = absoluteColumn + 1
                    continue
                default:
                    break
                }
                current.append(c)
                absoluteColumn += 1
            }

            let tail = current.trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty {
                let leadingWhitespace = current.prefix { $0.isWhitespace }.count
                result.append(tail)
                columns.append(tokenStartColumn + leadingWhitespace)
            }
            if parenDepth != 0 || angleDepth != 0 || bracketDepth != 0 || braceDepth != 0 {
                throw UrkelParseError(line: line, column: max(baseColumn, absoluteColumn), message: "Unbalanced delimiters in parameter list")
            }
            return zip(result, columns).map { ($0.0, $0.1) }
        }

        func parseParameter(_ raw: String, line: Int, baseColumn: Int) throws -> MachineAST.Parameter {
            guard let split = raw.firstIndex(of: ":") else {
                throw UrkelParseError(line: line, column: baseColumn, message: "Expected parameter in form name: Type")
            }
            let rawName = String(raw[..<split]).trimmingCharacters(in: .whitespaces)
            let rawType = String(raw[raw.index(after: split)...]).trimmingCharacters(in: .whitespaces)
            guard isIdentifier(rawName) else {
                throw UrkelParseError(line: line, column: baseColumn, message: "Invalid parameter name '\(rawName)'")
            }
            guard !rawType.isEmpty else {
                throw UrkelParseError(line: line, column: baseColumn, message: "Missing parameter type for '\(rawName)'")
            }
            let range = MachineAST.SourceRange(
                start: .init(line: line, column: baseColumn),
                end: .init(line: line, column: baseColumn + max(raw.count - 1, 0))
            )
            return MachineAST.Parameter(name: rawName, type: rawType, range: range)
        }

        func parseParameters(_ raw: String, line: Int, baseColumn: Int) throws -> [MachineAST.Parameter] {
            let trimmedRaw = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmedRaw.isEmpty else { return [] }
            return try splitTopLevelCommas(trimmedRaw, line: line, baseColumn: baseColumn).map {
                try parseParameter($0.text, line: line, baseColumn: $0.startColumn)
            }
        }

        func splitTransitionArrows(_ raw: String, line: Int) throws -> [(text: String, startColumn: Int)] {
            var result: [String] = []
            var columns: [Int] = []
            var current = ""
            var parenDepth = 0
            let chars = Array(raw)
            var i = 0
            var tokenStartColumn = 1

            while i < chars.count {
                let c = chars[i]
                if c == "(" {
                    parenDepth += 1
                } else if c == ")" {
                    parenDepth -= 1
                    if parenDepth < 0 {
                        throw UrkelParseError(line: line, column: i + 1, message: "Unbalanced closing ')' in transition declaration")
                    }
                }

                if parenDepth == 0, i + 1 < chars.count, chars[i] == "-", chars[i + 1] == ">" {
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    columns.append(tokenStartColumn)
                    current.removeAll(keepingCapacity: true)
                    i += 2
                    tokenStartColumn = i + 1
                    continue
                }

                current.append(c)
                i += 1
            }

            result.append(current.trimmingCharacters(in: .whitespaces))
            columns.append(tokenStartColumn)
            if parenDepth != 0 {
                throw UrkelParseError(line: line, column: max(1, raw.count), message: "Unbalanced parentheses in transition declaration")
            }
            return zip(result, columns).map { ($0.0, $0.1) }
        }

        func sourceRange(line: Int, rawLine: String, token: String, occurrence: Int = 1) -> MachineAST.SourceRange? {
            guard occurrence > 0 else { return nil }
            var searchStart = rawLine.startIndex
            var foundRange: Range<String.Index>?
            var remaining = occurrence

            while remaining > 0 {
                guard let range = rawLine.range(of: token, range: searchStart..<rawLine.endIndex) else {
                    return nil
                }
                foundRange = range
                searchStart = range.upperBound
                remaining -= 1
            }

            guard let range = foundRange else { return nil }
            let start = rawLine.distance(from: rawLine.startIndex, to: range.lowerBound) + 1
            let end = start + max(token.count - 1, 0)
            return .init(start: .init(line: line, column: start), end: .init(line: line, column: end))
        }

        func skipTrivia() {
            while index < lines.count, isTrivia(lines[index]) {
                index += 1
            }
        }

        skipTrivia()

        if index < lines.count, trimmed(lines[index]) == "@imports" {
            index += 1
            while index < lines.count {
                if isTrivia(lines[index]) {
                    index += 1
                    continue
                }
                let line = trimmed(lines[index])
                if line.hasPrefix("import ") {
                    let importedType = String(line.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
                    if !importedType.isEmpty {
                        imports.append(importedType)
                    }
                    index += 1
                    continue
                }
                break
            }
        }

        skipTrivia()

        if index < lines.count {
            let line = trimmed(lines[index])
            if line.hasPrefix("machine ") {
                let pattern = #"^machine\s+([A-Za-z][A-Za-z0-9_]*)(?:\s*<\s*([A-Za-z][A-Za-z0-9_]*)\s*>)?$"#
                guard let match = line.range(of: pattern, options: .regularExpression) else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid machine declaration")
                }
                let capture = String(line[match])
                let prefixRemoved = capture.dropFirst("machine".count).trimmingCharacters(in: .whitespaces)

                if let genericStart = prefixRemoved.firstIndex(of: "<"), let genericEnd = prefixRemoved.lastIndex(of: ">"), genericStart < genericEnd {
                    machineName = String(prefixRemoved[..<genericStart]).trimmingCharacters(in: .whitespaces)
                    contextType = String(prefixRemoved[prefixRemoved.index(after: genericStart)..<genericEnd]).trimmingCharacters(in: .whitespaces)
                } else {
                    machineName = prefixRemoved
                }

                guard isIdentifier(machineName) else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid machine name '\(machineName)'")
                }

                index += 1
            }
        }

        skipTrivia()

        if index < lines.count {
            let line = trimmed(lines[index])
            if line.hasPrefix("@factory ") {
                let pattern = #"^@factory\s+([A-Za-z][A-Za-z0-9_]*)\((.*)\)$"#
                guard let range = line.range(of: pattern, options: .regularExpression) else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid @factory declaration")
                }
                let matched = String(line[range])
                let openParen = matched.firstIndex(of: "(")!
                let closeParen = matched.lastIndex(of: ")")!
                let name = matched[matched.index(matched.startIndex, offsetBy: "@factory".count)..<openParen]
                    .trimmingCharacters(in: .whitespaces)
                guard isIdentifier(name) else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid factory name '\(name)'")
                }
                let rawParameters = String(matched[matched.index(after: openParen)..<closeParen])
                let parameterColumn = line.distance(from: line.startIndex, to: matched.index(after: openParen)) + 1
                let parsedParameters = try parseParameters(rawParameters, line: index + 1, baseColumn: parameterColumn)
                let rangeValue = sourceRange(line: index + 1, rawLine: lines[index], token: matched)
                factory = MachineAST.Factory(name: name, parameters: parsedParameters, range: rangeValue)
                index += 1
            }
        }

        skipTrivia()

        guard index < lines.count, trimmed(lines[index]) == "@states" else {
            throw UrkelParseError(line: index + 1, column: 1, message: "Expected @states block")
        }
        index += 1

        while index < lines.count {
            if isTrivia(lines[index]) {
                index += 1
                continue
            }
            let line = trimmed(lines[index])
            if line == "@transitions" {
                break
            }

            let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard parts.count == 2 else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid state statement")
            }
            let kindText = parts[0]
            let stateName = parts[1]
            guard isIdentifier(stateName) else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid state identifier '\(stateName)'")
            }

            let kind: MachineAST.StateNode.Kind
            switch kindText {
            case "init": kind = .initial
            case "state": kind = .normal
            case "final": kind = .terminal
            default:
                throw UrkelParseError(line: index + 1, column: 1, message: "Unknown state kind '\(kindText)'")
            }

            let rangeValue = sourceRange(line: index + 1, rawLine: lines[index], token: stateName)
            states.append(.init(name: stateName, kind: kind, range: rangeValue))
            index += 1
        }

        guard index < lines.count, trimmed(lines[index]) == "@transitions" else {
            throw UrkelParseError(line: index + 1, column: 1, message: "Expected @transitions block")
        }
        index += 1

        while index < lines.count {
            if isTrivia(lines[index]) {
                index += 1
                continue
            }

            let rawLine = lines[index]
            let line = trimmed(rawLine)
            let parts = try splitTransitionArrows(line, line: index + 1)
            guard parts.count == 3 else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Transition must follow: State -> event(params?) -> State")
            }

            let leadingWhitespaceOffset = rawLine.distance(from: rawLine.startIndex, to: rawLine.firstIndex(where: { !$0.isWhitespace }) ?? rawLine.endIndex)
            func absoluteColumn(_ columnInTrimmedLine: Int) -> Int {
                leadingWhitespaceOffset + columnInTrimmedLine
            }

            let from = parts[0].text
            let eventDecl = parts[1].text
            let to = parts[2].text

            guard isIdentifier(from) else {
                throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[0].startColumn), message: "Invalid source state '\(from)'")
            }
            guard isIdentifier(to) else {
                throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[2].startColumn), message: "Expected transition target state")
            }

            let eventName: String
            let eventParameters: [MachineAST.Parameter]
            if let openParen = eventDecl.firstIndex(of: "(") {
                guard let closeParen = eventDecl.lastIndex(of: ")"), openParen < closeParen else {
                    throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[1].startColumn), message: "Malformed event declaration")
                }
                eventName = String(eventDecl[..<openParen]).trimmingCharacters(in: .whitespaces)
                let payload = String(eventDecl[eventDecl.index(after: openParen)..<closeParen])
                let payloadColumn = absoluteColumn(parts[1].startColumn + eventDecl.distance(from: eventDecl.startIndex, to: openParen) + 1)
                eventParameters = try parseParameters(payload, line: index + 1, baseColumn: payloadColumn)
            } else {
                eventName = eventDecl
                eventParameters = []
            }

            guard isIdentifier(eventName) else {
                throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[1].startColumn), message: "Invalid event name '\(eventName)'")
            }

            let rangeValue = sourceRange(line: index + 1, rawLine: lines[index], token: eventDecl)
            transitions.append(.init(from: from, event: eventName, parameters: eventParameters, to: to, range: rangeValue))
            index += 1
        }

        if states.isEmpty {
            throw UrkelParseError(line: 1, column: 1, message: "Machine must declare at least one state")
        }

        let astRange = MachineAST.SourceRange(
            start: .init(line: 1, column: 1),
            end: .init(line: sourceLineCount, column: max(lines.last?.count ?? 1, 1))
        )

        return MachineAST(
            imports: imports,
            machineName: machineName,
            contextType: contextType,
            factory: factory,
            states: states,
            transitions: transitions,
            range: astRange
        )
    }

    public func parseParameter(source: String) throws -> MachineAST.Parameter {
        try parse(source: """
        machine Example
        @states
          init Idle
        @transitions
          Idle -> go(\(source)) -> Idle
        """).transitions[0].parameters[0]
    }

    public func print(ast: MachineAST) -> String {
        var lines: [String] = []

        if !ast.imports.isEmpty {
            lines.append("@imports")
            lines.append(contentsOf: ast.imports.map { "  import \($0)" })
            lines.append("")
        }

        if let contextType = ast.contextType {
            lines.append("machine \(ast.machineName)<\(contextType)>")
        } else {
            lines.append("machine \(ast.machineName)")
        }

        if let factory = ast.factory {
            let params = factory.parameters
                .map { "\($0.name): \($0.type)" }
                .joined(separator: ", ")
            lines.append("@factory \(factory.name)(\(params))")
        }

        lines.append("@states")
        lines.append(contentsOf: ast.states.map { state in
            let kind: String
            switch state.kind {
            case .initial: kind = "init"
            case .normal: kind = "state"
            case .terminal: kind = "final"
            }
            return "  \(kind) \(state.name)"
        })

        lines.append("@transitions")
        lines.append(contentsOf: ast.transitions.map { transition in
            let params = transition.parameters
                .map { "\($0.name): \($0.type)" }
                .joined(separator: ", ")
            let eventDecl = params.isEmpty ? transition.event : "\(transition.event)(\(params))"
            return "  \(transition.from) -> \(eventDecl) -> \(transition.to)"
        })

        return lines.joined(separator: "\n")
    }
}

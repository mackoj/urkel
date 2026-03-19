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

        func splitTopLevelCommas(_ raw: String, line: Int) throws -> [String] {
            var result: [String] = []
            var current = ""
            var parenDepth = 0
            var angleDepth = 0
            var bracketDepth = 0
            var braceDepth = 0

            for scalar in raw.unicodeScalars {
                let c = Character(scalar)
                switch c {
                case "(": parenDepth += 1
                case ")":
                    parenDepth -= 1
                    if parenDepth < 0 {
                        throw UrkelParseError(line: line, column: 1, message: "Unbalanced closing ')' in parameter list")
                    }
                case "<": angleDepth += 1
                case ">":
                    angleDepth -= 1
                    if angleDepth < 0 {
                        throw UrkelParseError(line: line, column: 1, message: "Unbalanced closing '>' in parameter list")
                    }
                case "[": bracketDepth += 1
                case "]":
                    bracketDepth -= 1
                    if bracketDepth < 0 {
                        throw UrkelParseError(line: line, column: 1, message: "Unbalanced closing ']' in parameter list")
                    }
                case "{": braceDepth += 1
                case "}":
                    braceDepth -= 1
                    if braceDepth < 0 {
                        throw UrkelParseError(line: line, column: 1, message: "Unbalanced closing '}' in parameter list")
                    }
                case "," where parenDepth == 0 && angleDepth == 0 && bracketDepth == 0 && braceDepth == 0:
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    current.removeAll(keepingCapacity: true)
                    continue
                default:
                    break
                }
                current.append(c)
            }

            let tail = current.trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty {
                result.append(tail)
            }
            if parenDepth != 0 || angleDepth != 0 || bracketDepth != 0 || braceDepth != 0 {
                throw UrkelParseError(line: line, column: 1, message: "Unbalanced delimiters in parameter list")
            }
            return result
        }

        func parseParameter(_ raw: String, line: Int) throws -> MachineAST.Parameter {
            guard let split = raw.firstIndex(of: ":") else {
                throw UrkelParseError(line: line, column: 1, message: "Expected parameter in form name: Type")
            }
            let rawName = String(raw[..<split]).trimmingCharacters(in: .whitespaces)
            let rawType = String(raw[raw.index(after: split)...]).trimmingCharacters(in: .whitespaces)
            guard isIdentifier(rawName) else {
                throw UrkelParseError(line: line, column: 1, message: "Invalid parameter name '\(rawName)'")
            }
            guard !rawType.isEmpty else {
                throw UrkelParseError(line: line, column: 1, message: "Missing parameter type for '\(rawName)'")
            }
            return MachineAST.Parameter(name: rawName, type: rawType)
        }

        func parseParameters(_ raw: String, line: Int) throws -> [MachineAST.Parameter] {
            let trimmedRaw = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmedRaw.isEmpty else { return [] }
            return try splitTopLevelCommas(trimmedRaw, line: line).map { try parseParameter($0, line: line) }
        }

        func splitTransitionArrows(_ raw: String, line: Int) throws -> [String] {
            var result: [String] = []
            var current = ""
            var parenDepth = 0
            let chars = Array(raw)
            var i = 0

            while i < chars.count {
                let c = chars[i]
                if c == "(" {
                    parenDepth += 1
                } else if c == ")" {
                    parenDepth -= 1
                    if parenDepth < 0 {
                        throw UrkelParseError(line: line, column: 1, message: "Unbalanced closing ')' in transition declaration")
                    }
                }

                if parenDepth == 0, i + 1 < chars.count, chars[i] == "-", chars[i + 1] == ">" {
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    current.removeAll(keepingCapacity: true)
                    i += 2
                    continue
                }

                current.append(c)
                i += 1
            }

            result.append(current.trimmingCharacters(in: .whitespaces))
            if parenDepth != 0 {
                throw UrkelParseError(line: line, column: 1, message: "Unbalanced parentheses in transition declaration")
            }
            return result
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
                factory = MachineAST.Factory(name: name, parameters: try parseParameters(rawParameters, line: index + 1))
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

            states.append(.init(name: stateName, kind: kind))
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

            let line = trimmed(lines[index])
            let parts = try splitTransitionArrows(line, line: index + 1)
            guard parts.count == 3 else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Transition must follow: State -> event(params?) -> State")
            }

            let from = parts[0]
            let eventDecl = parts[1]
            let to = parts[2]

            guard isIdentifier(from) else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid source state '\(from)'")
            }
            guard isIdentifier(to) else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Expected transition target state")
            }

            let eventName: String
            let eventParameters: [MachineAST.Parameter]
            if let openParen = eventDecl.firstIndex(of: "(") {
                guard let closeParen = eventDecl.lastIndex(of: ")"), openParen < closeParen else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Malformed event declaration")
                }
                eventName = String(eventDecl[..<openParen]).trimmingCharacters(in: .whitespaces)
                let payload = String(eventDecl[eventDecl.index(after: openParen)..<closeParen])
                eventParameters = try parseParameters(payload, line: index + 1)
            } else {
                eventName = eventDecl
                eventParameters = []
            }

            guard isIdentifier(eventName) else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid event name '\(eventName)'")
            }

            transitions.append(.init(from: from, event: eventName, parameters: eventParameters, to: to))
            index += 1
        }

        if states.isEmpty {
            throw UrkelParseError(line: 1, column: 1, message: "Machine must declare at least one state")
        }

        return MachineAST(
            imports: imports,
            machineName: machineName,
            contextType: contextType,
            factory: factory,
            states: states,
            transitions: transitions
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
}

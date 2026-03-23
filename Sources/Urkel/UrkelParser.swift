import Foundation
import Parsing

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

private enum UrkelInternalParseError: Error {
    case invalidFactoryDeclaration
}

public struct UrkelParser {
    public init() {}

    public func parse(source: String, machineNameFallback: String? = nil) throws -> MachineAST {
        let lines = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var index = 0
        var machineName = machineNameFallback ?? "Machine"
        var contextType: String?
        var factory: MachineAST.Factory?
        var composedMachines: [String] = []
        var states: [MachineAST.StateNode] = []
        var transitions: [MachineAST.TransitionNode] = []
        var pendingDocComments: [MachineAST.DocComment] = []
        let sourceLineCount = max(lines.count, 1)

        func trimmed(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespaces)
        }

        func isDeprecatedImportsSyntax(_ value: String) -> Bool {
            let t = trimmed(value)
            return t == "@imports" || t.hasPrefix("import ")
        }

        func throwDeprecatedImportsSyntax(line: Int) throws -> Never {
            throw UrkelParseError(
                line: line,
                column: 1,
                message: "`@imports` is no longer supported. Configure imports in urkel-config.json using imports.swift or imports.<language>."
            )
        }

        func consumePendingDocComments() -> [MachineAST.DocComment] {
            defer { pendingDocComments.removeAll() }
            return pendingDocComments
        }

        let identifierParser = UrkelIdentifierParser()

        func isIdentifier(_ value: String) -> Bool {
            var input = value[...]
            guard let parsed = try? identifierParser.parse(&input) else { return false }
            return parsed == value && input.isEmpty
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

                if parenDepth == 0, i + 1 < chars.count, chars[i] == "=", chars[i + 1] == ">" {
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    columns.append(tokenStartColumn)
                    current.removeAll(keepingCapacity: true)
                    i += 2
                    tokenStartColumn = i + 1
                    continue
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

        func drainDocComments() {
            while index < lines.count {
                let rawLine = lines[index]
                let trimmedLine = trimmed(rawLine)

                if trimmedLine.isEmpty {
                    pendingDocComments.removeAll()
                    index += 1
                    continue
                }

                if trimmedLine.hasPrefix("#") {
                    let commentBody = String(trimmedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                    let commentRange = sourceRange(line: index + 1, rawLine: rawLine, token: "#")
                    pendingDocComments.append(.init(text: commentBody, range: commentRange))
                    index += 1
                    continue
                }

                break
            }
        }

        drainDocComments()
        if index < lines.count, isDeprecatedImportsSyntax(lines[index]) {
            try throwDeprecatedImportsSyntax(line: index + 1)
        }
        pendingDocComments.removeAll()

        if index < lines.count {
            let machineLineParser = UrkelMachineLineParser()
            let line = trimmed(lines[index])
            if line.hasPrefix("machine ") {
                let parsedMachine: UrkelMachineLineParser.Output
                do {
                    parsedMachine = try machineLineParser.parse(line[...])
                } catch {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid machine declaration")
                }
                machineName = parsedMachine.name
                contextType = parsedMachine.contextType

                guard isIdentifier(machineName) else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid machine name '\(machineName)'")
                }

                index += 1
                pendingDocComments.removeAll()
            }
        }

        drainDocComments()
        if index < lines.count, isDeprecatedImportsSyntax(lines[index]) {
            try throwDeprecatedImportsSyntax(line: index + 1)
        }

        while index < lines.count {
            let composeLineParser = UrkelComposeLineParser()
            let line = trimmed(lines[index])
            guard line.hasPrefix("@compose ") else { break }

            let composedMachine: String
            do {
                composedMachine = try composeLineParser.parse(line[...])
            } catch {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid @compose declaration")
            }

            guard isIdentifier(composedMachine) else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid composed machine identifier '\(composedMachine)'")
            }

            if !composedMachines.contains(composedMachine) {
                composedMachines.append(composedMachine)
            }
            index += 1
            pendingDocComments.removeAll()
            drainDocComments()
            if index < lines.count, isDeprecatedImportsSyntax(lines[index]) {
                try throwDeprecatedImportsSyntax(line: index + 1)
            }
        }

        if index < lines.count {
            let factoryLineParser = UrkelFactoryLineParser()
            let line = trimmed(lines[index])
            if line.hasPrefix("@factory ") {
                let parsedFactory: UrkelFactoryLineParser.Output
                do {
                    parsedFactory = try factoryLineParser.parse(line[...])
                } catch {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid @factory declaration")
                }
                let name = parsedFactory.name
                guard isIdentifier(name) else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid factory name '\(name)'")
                }
                let openParen = line.firstIndex(of: "(")!
                let rawParameters = parsedFactory.rawParameters
                let parameterColumn = line.distance(from: line.startIndex, to: line.index(after: openParen)) + 1
                let parsedParameters = try parseParameters(rawParameters, line: index + 1, baseColumn: parameterColumn)
                let rangeValue = sourceRange(line: index + 1, rawLine: lines[index], token: line)
                factory = MachineAST.Factory(name: name, parameters: parsedParameters, range: rangeValue)
                index += 1
                pendingDocComments.removeAll()
            }
        }

        drainDocComments()
        if index < lines.count, isDeprecatedImportsSyntax(lines[index]) {
            try throwDeprecatedImportsSyntax(line: index + 1)
        }
        pendingDocComments.removeAll()

        guard index < lines.count, trimmed(lines[index]) == "@states" else {
            throw UrkelParseError(line: index + 1, column: 1, message: "Expected @states block")
        }
        index += 1

        while index < lines.count {
            drainDocComments()
            guard index < lines.count else { break }

            let stateLineParser = UrkelStateLineParser()
            let line = trimmed(lines[index])
            if line == "@transitions" {
                pendingDocComments.removeAll()
                break
            }
            if isDeprecatedImportsSyntax(line) {
                try throwDeprecatedImportsSyntax(line: index + 1)
            }

            let stateDocComments = consumePendingDocComments()
            let parsedState: UrkelStateLineParser.Output
            do {
                parsedState = try stateLineParser.parse(line[...])
            } catch {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid state statement")
            }
            let stateName = parsedState.name
            guard isIdentifier(stateName) else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Invalid state identifier '\(stateName)'")
            }

            let kind: MachineAST.StateNode.Kind
            switch parsedState.kindText {
            case "init": kind = .initial
            case "state": kind = .normal
            case "final": kind = .terminal
            default:
                throw UrkelParseError(line: index + 1, column: 1, message: "Unknown state kind '\(parsedState.kindText)'")
            }

            let rangeValue = sourceRange(line: index + 1, rawLine: lines[index], token: stateName)
            states.append(.init(name: stateName, kind: kind, range: rangeValue, docComments: stateDocComments))
            index += 1
        }

        guard index < lines.count, trimmed(lines[index]) == "@transitions" else {
            throw UrkelParseError(line: index + 1, column: 1, message: "Expected @transitions block")
        }
        index += 1

        while index < lines.count {
            drainDocComments()
            guard index < lines.count else { break }

            if isDeprecatedImportsSyntax(lines[index]) {
                try throwDeprecatedImportsSyntax(line: index + 1)
            }

            let transitionDocComments = consumePendingDocComments()
            let rawLine = lines[index]
            let line = trimmed(rawLine)
            if line.isEmpty { index += 1; continue }
            if line.hasPrefix("@") { break }
            let parts = try splitTransitionArrows(line, line: index + 1)
            guard parts.count == 2 || parts.count == 3 || parts.count == 4 else {
                throw UrkelParseError(line: index + 1, column: 1, message: "Transition must follow: State -> event(params?) -> State [=> Machine.init] OR State -> event(params?)")
            }
            if parts.count == 2, parts[1].text.isEmpty {
                throw UrkelParseError(line: index + 1, column: 1, message: "Transition must follow: State -> event(params?) -> State [=> Machine.init] OR State -> event(params?)")
            }

            let leadingWhitespaceOffset = rawLine.distance(from: rawLine.startIndex, to: rawLine.firstIndex(where: { !$0.isWhitespace }) ?? rawLine.endIndex)
            func absoluteColumn(_ columnInTrimmedLine: Int) -> Int {
                leadingWhitespaceOffset + columnInTrimmedLine
            }

            let from = parts[0].text
            let eventDecl = parts[1].text
            let to: String?
            let spawnedMachine: String?
            if parts.count == 2 {
                to = nil
                spawnedMachine = nil
            } else {
                to = parts[2].text
                if parts.count == 4 {
                    let forkDecl = parts[3].text
                    guard forkDecl.hasSuffix(".init") else {
                        throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[3].startColumn), message: "Fork target must end with .init")
                    }
                    let rawMachine = String(forkDecl.dropLast(".init".count)).trimmingCharacters(in: .whitespaces)
                    guard isIdentifier(rawMachine) else {
                        throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[3].startColumn), message: "Invalid composed machine identifier '\(rawMachine)'")
                    }
                    spawnedMachine = rawMachine
                } else {
                    spawnedMachine = nil
                }
            }

            guard isIdentifier(from) else {
                throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[0].startColumn), message: "Invalid source state '\(from)'")
            }
            if let to = to {
                guard isIdentifier(to) else {
                    throw UrkelParseError(line: index + 1, column: absoluteColumn(parts[2].startColumn), message: "Expected transition target state")
                }
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
            transitions.append(
                .init(
                    from: from,
                    event: eventName,
                    parameters: eventParameters,
                    to: to,
                    spawnedMachine: spawnedMachine,
                    range: rangeValue,
                    docComments: transitionDocComments
                )
            )
            index += 1
        }

        if states.isEmpty {
            throw UrkelParseError(line: 1, column: 1, message: "Machine must declare at least one state")
        }

        // Parse optional @continuation block
        var continuations: [String: String] = [:]
        if index < lines.count, trimmed(lines[index]) == "@continuation" {
            index += 1
            while index < lines.count {
                let cline = trimmed(lines[index])
                if cline.isEmpty || cline.hasPrefix("#") {
                    index += 1
                    continue
                }
                if cline.hasPrefix("@") { break }
                if let arrowRange = cline.range(of: " -> ") {
                    let eventName = String(cline[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let returnType = String(cline[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    guard isIdentifier(eventName), !returnType.isEmpty else {
                        throw UrkelParseError(line: index + 1, column: 1, message: "Invalid @continuation entry. Expected: eventName -> SwiftType")
                    }
                    continuations[eventName] = returnType
                } else {
                    throw UrkelParseError(line: index + 1, column: 1, message: "Invalid @continuation entry. Expected: eventName -> SwiftType")
                }
                index += 1
            }
        }

        let astRange = MachineAST.SourceRange(
            start: .init(line: 1, column: 1),
            end: .init(line: sourceLineCount, column: max(lines.last?.count ?? 1, 1))
        )

        return MachineAST(
            imports: [],
            machineName: machineName,
            contextType: contextType,
            factory: factory,
            composedMachines: composedMachines,
            states: states,
            transitions: transitions,
            continuations: continuations,
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

        if let contextType = ast.contextType {
            lines.append("machine \(ast.machineName)<\(contextType)>")
        } else {
            lines.append("machine \(ast.machineName)")
        }

        if !ast.composedMachines.isEmpty {
            lines.append(contentsOf: ast.composedMachines.map { "@compose \($0)" })
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
            if let to = transition.to {
                let forkSuffix = transition.spawnedMachine.map { " => \($0).init" } ?? ""
                return "  \(transition.from) -> \(eventDecl) -> \(to)\(forkSuffix)"
            } else {
                return "  \(transition.from) -> \(eventDecl)"
            }
        })

        if !ast.continuations.isEmpty {
            lines.append("@continuation")
            for (event, returnType) in ast.continuations.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(event) -> \(returnType)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

private struct UrkelIdentifierParser: Parser {
    func parse(_ input: inout Substring) throws -> String {
        let parser = Parse(input: Substring.self) {
            Prefix(1...) { $0.isLetter }
            Prefix { $0.isLetter || $0.isNumber || $0 == "_" }
        }
        let (head, tail) = try parser.parse(&input)
        return String(head) + String(tail)
    }
}

private struct UrkelComposeLineParser: Parser {
    func parse(_ input: inout Substring) throws -> String {
        let parser = Parse(input: Substring.self) {
            "@compose"
            Skip { Prefix(1...) { $0.isWhitespace } }
            UrkelIdentifierParser()
            End()
        }
        return try parser.parse(&input)
    }
}

private struct UrkelMachineLineParser: Parser {
    struct Output {
        let name: String
        let contextType: String?
    }

    func parse(_ input: inout Substring) throws -> Output {
        let parser = Parse(input: Substring.self) {
            "machine"
            Skip { Prefix(1...) { $0.isWhitespace } }
            UrkelIdentifierParser()
            Optionally {
                Skip { Prefix { $0.isWhitespace } }
                "<"
                Skip { Prefix { $0.isWhitespace } }
                UrkelIdentifierParser()
                Skip { Prefix { $0.isWhitespace } }
                ">"
            }
            End()
        }

        let parsed = try parser.parse(&input)
        return Output(name: parsed.0, contextType: parsed.1)
    }
}

private struct UrkelFactoryLineParser: Parser {
    struct Output {
        let name: String
        let rawParameters: String
    }

    func parse(_ input: inout Substring) throws -> Output {
        let parser = Parse(input: Substring.self) {
            "@factory"
            Skip { Prefix(1...) { $0.isWhitespace } }
            UrkelIdentifierParser()
            "("
            Prefix { _ in true }
        }
        let parsed = try parser.parse(&input)
        let name = parsed.0
        let tail = parsed.1

        guard tail.last == ")" else {
            throw UrkelInternalParseError.invalidFactoryDeclaration
        }
        let parameters = String(tail.dropLast())
        return Output(name: name, rawParameters: parameters)
    }
}

private struct UrkelStateLineParser: Parser {
    struct Output {
        let kindText: String
        let name: String
    }

    func parse(_ input: inout Substring) throws -> Output {
        let parser = Parse(input: Substring.self) {
            Prefix(1...) { $0.isLetter }
            Skip { Prefix(1...) { $0.isWhitespace } }
            UrkelIdentifierParser()
            End()
        }
        let parsed = try parser.parse(&input)
        return Output(kindText: String(parsed.0), name: parsed.1)
    }
}

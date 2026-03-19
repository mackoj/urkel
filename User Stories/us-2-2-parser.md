# US-2.2: Implement the Parser Combinator (EBNF Engine)

## 1. Objective
Build the parsing engine that reads raw `.urkel` text and converts it into a `MachineAST` object using Point-Free's `swift-parsing` library, directly mirroring the formal `grammar.ebnf` file.

## 2. Context
With the formal EBNF grammar defined in the repository, standard Regex is too brittle to handle flexible whitespace, optional blocks, and nested parameters reliably. By using a parser combinator library, we can write modular, type-safe Swift code where each rule in `grammar.ebnf` becomes a distinct, testable Swift parser (e.g., `WhitespaceParser`, `ParameterParser`). Crucially, this library provides exact line and column error reporting out-of-the-box, which is a hard requirement for the Language Server (LSP) planned in Epic 6.

## 3. Acceptance Criteria
* **Given** the Urkel package dependencies.
* **When** resolving packages.
* **Then** `pointfreeco/swift-parsing` (version 0.13.0 or later) is successfully fetched.
* **Given** a valid `Bluetooth.urkel` file string that perfectly conforms to `grammar.ebnf`.
* **When** `UrkelParser.parse(source:)` is called.
* **Then** it ignores all comments/whitespace and returns a fully populated `MachineAST`.
* **Given** a malformed transition string that violates `grammar.ebnf` (e.g., `Idle -> start -> ` missing the target state).
* **When** parsed.
* **Then** it throws a detailed `swift-parsing` error indicating the exact line, column, and expected EBNF token where the syntax deviated.

## 4. Implementation Details
* Add `.package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0")` to `Package.swift`.
* Create `public struct UrkelParser`.
* **Strict EBNF Adherence:** Open `grammar.ebnf`. For every rule defined in that file, create a corresponding Swift parser.
* Implement base lexical parsers for EBNF terminals: `Whitespace`, `Identifier`, `SwiftType`.
* Implement combinatorial parsers for structures: `ParameterListParser`, `EventDeclParser`, `TransitionStmtParser`.
* Combine them into a master `UrkelFileParser` that returns a `MachineAST`.
* **BYOT Implementation:** Handle the "Bring Your Own Types" rule (`SwiftType` in the EBNF) by writing a parser that captures everything after a `:` up to the next comma or newline as a raw `String`.

## 5. Testing Strategy
* **Unit Tests:** Create `UrkelParserTests`. Do not just test the whole file; test the individual EBNF combinators against the exact rules in `grammar.ebnf`.
* Pass `"device: [String: Any]?"` to `ParameterParser` and assert it successfully captures `name: "device"` and `type: "[String: Any]?"`.
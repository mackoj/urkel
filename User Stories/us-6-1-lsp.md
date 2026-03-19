# US-6.1: Implement the Urkel Language Server (LSP)

## 1. Objective
Build a standalone executable target (`urkel-lsp`) that implements the Language Server Protocol over stdio, providing real-time diagnostics, syntax validation, and EBNF-driven autocomplete for `.urkel` files in compatible editors.

## 2. Context
Currently, a developer only knows they made a mistake when they run `urkel generate`. An LSP bridges our existing `UrkelParser` and `UrkelValidator` directly into the text editor. By listening to live keystrokes, the LSP can instantly parse the document against `grammar.ebnf`, run the validator, and send back error ranges to underline mistakes in real-time.

## 3. Acceptance Criteria
* **Given** a developer has the Urkel extension installed and opens a `.urkel` file.
* **When** they type an invalid transition that passes `grammar.ebnf` but fails domain logic (e.g., `Idle -> start -> UndefinedState`).
* **Then** the LSP publishes a diagnostic error: "Unresolved state reference: UndefinedState".
* **Given** a developer deletes the `init` state from the `@states` block.
* **When** the file is modified.
* **Then** the LSP publishes a diagnostic error: "Machine is missing exactly one initial state."
* **Given** the developer triggers autocomplete inside a `@states` or `@transitions` block, including a partially written line.
* **When** they are typing.
* **Then** the LSP suggests grammar-driven snippets plus known state/event symbols from the current document, even if the file is not fully parseable yet.

## 4. Implementation Details
* Define a new executable target in `Package.swift` named `UrkelLSP`.
* Import a robust Swift LSP library (e.g., `ChimeHQ/LanguageServerProtocol`).
* Implement the core LSP lifecycle methods: `initialize`, `initialized`, and `shutdown`.
* **State Management:** Maintain an in-memory dictionary of open documents (`[DocumentURI: String]`), updated via `textDocument/didOpen` and `textDocument/didChange`.
* **Diagnostics Pipeline:** On every `didChange` event:
  1. Pass the in-memory string to `UrkelParser.parse(source:)`. If this fails, map the `swift-parsing` EBNF error to a syntax Diagnostic.
  2. If parsing succeeds, pass the AST to `UrkelValidator.validate(ast:)`. Map thrown graph errors to semantic Diagnostics.
  3. Send a `textDocument/publishDiagnostics` notification back to the client.

## 5. Testing Strategy
* **Unit Tests:** Write tests that instantiate the `UrkelLanguageServer` class, send it a mock `didChange` JSON-RPC payload containing a string that violates `grammar.ebnf`, and assert that the server responds with a `publishDiagnostics` payload containing the correct line number and syntax error.

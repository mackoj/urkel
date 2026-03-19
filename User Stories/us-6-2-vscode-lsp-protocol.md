# US-6.2: Implement Full Microsoft LSP Protocol Compatibility for VS Code

## 1. Objective
Upgrade `urkel-lsp` from the current line-based diagnostics executable into a standards-compliant Language Server Protocol (LSP) server over stdio, so it is directly pluggable into VS Code and any LSP-compatible editor without custom adapters.

## 2. Context
US-6.1 established the language diagnostics core (parser + validator integration), but the current executable does not yet speak Microsoft LSP wire protocol (JSON-RPC with `Content-Length` framing). As a result, it cannot be launched by VS Code's language client. This story closes that integration gap by implementing the protocol transport layer and core editor-facing methods, while reusing the existing Urkel diagnostics pipeline.

## 3. Acceptance Criteria
* **Given** `urkel-lsp` is launched by a VS Code language client over stdio.
* **When** the client sends an `initialize` request.
* **Then** the server responds with valid `ServerCapabilities` including text document sync and diagnostic support.

* **Given** a `.urkel` document is opened in VS Code.
* **When** `textDocument/didOpen` is sent with document text.
* **Then** the server runs parse/validate and sends `textDocument/publishDiagnostics` notifications.

* **Given** a document change in VS Code.
* **When** `textDocument/didChange` is sent.
* **Then** diagnostics are recomputed and republished for the same URI, clearing previous errors when fixed.

* **Given** the client sends `shutdown` followed by `exit`.
* **When** the sequence is processed.
* **Then** the server terminates gracefully with protocol-compliant behavior.

* **Given** malformed or unknown JSON-RPC messages.
* **When** received by the server.
* **Then** they are handled safely (error response or ignored per spec) without crashing.

## 4. Implementation Details
* Replace the current line loop in `Sources/UrkelLSP/main.swift` with an LSP stdio transport loop:
  * Parse `Content-Length` headers.
  * Read exact JSON payload bytes.
  * Decode JSON-RPC 2.0 envelopes.
* Implement typed request/notification handlers for at least:
  * `initialize`
  * `initialized`
  * `textDocument/didOpen`
  * `textDocument/didChange`
  * `textDocument/didClose`
  * `shutdown`
  * `exit`
* Keep open-document state keyed by URI and version.
* Reuse `UrkelParser` and `UrkelValidator` for diagnostics generation.
* Add mapping from parser/validator errors to LSP diagnostic ranges/severity/source.
* Return capabilities with incremental sync (`TextDocumentSyncKind.Incremental`) or full sync if incremental patching is deferred for V1.
* Ensure server logs (if any) do not corrupt stdout LSP stream (use stderr for logs).
* Optionally include a minimal `completion` provider if low-cost; otherwise defer to US-6.3.

## 5. Testing Strategy
* **Protocol unit tests:**
  * Feed framed JSON-RPC messages to the LSP transport parser and assert decoded message correctness.
  * Validate encoded responses include correct headers and valid JSON.
* **Integration tests (stdio):**
  * Spawn `urkel-lsp` as a process.
  * Send `initialize`, `didOpen`, `didChange`, `shutdown`, `exit` sequence.
  * Assert received `publishDiagnostics` messages and graceful termination.
* **Regression tests:**
  * Ensure existing parser/validator diagnostic semantics remain unchanged.

## 6. Out of Scope
* VS Code extension packaging/publishing.
* Semantic tokens, hover, go-to-definition, formatting, and code actions.
* Full incremental diff algorithm beyond baseline sync mode chosen for V1.

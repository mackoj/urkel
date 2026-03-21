# US-10.6: LSP Performance and Partial-AST Resilience

## 1. Objective
Make the Urkel language server more responsive on large files and more resilient while users type incomplete syntax.

## 2. Context
Current LSP flow reparses full documents frequently. As editor features grow (completion, hover, semantic tokens, actions), responsiveness and graceful degradation on partial input become critical.

## 3. Acceptance Criteria
* **Given** rapid typing in a `.urkel` file.
* **When** diagnostics/completion/hover are requested.
* **Then** latency remains low and UI stays responsive.

* **Given** partially typed transitions.
* **When** requesting completion and hover.
* **Then** server returns best-effort results instead of dropping features entirely.

* **Given** semantic token requests.
* **When** source has minor syntax errors.
* **Then** tokens are still produced for parseable regions.

## 4. Implementation Details
* Add lightweight partial parsing or fault-tolerant parse paths for editor features.
* Cache AST/token results by document version.
* Separate strict validation diagnostics from best-effort semantic services where appropriate.

## 5. Testing Strategy
* Performance smoke benchmarks for document updates.
* LSP integration tests with incomplete fixture documents.
* Regression tests ensuring diagnostics remain correct and stable.

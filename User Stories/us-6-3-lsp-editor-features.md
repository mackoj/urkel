# US-6.3: Production-Ready LSP Editor Features (Formatting + Semantic UX)

## 1. Objective
Add high-impact editor features on top of the protocol-compliant `urkel-lsp` server so `.urkel` authoring in VS Code feels first-class: formatting, semantic highlighting, intelligent completion, and actionable quick fixes.

## 2. Context
US-6.2 focuses on protocol compatibility and diagnostics transport. Once that baseline is done, developers still need strong day-to-day ergonomics to adopt Urkel comfortably in real teams. This story targets the "developer experience" layer: readable files, semantic colorization, context-aware completion, and quick recovery from common mistakes. Because semantic features require exact line/column offsets, this story also involves upgrading the core AST to track source ranges.

## 3. Acceptance Criteria
* **Given** a messy `.urkel` file with inconsistent indentation and spacing.
* **When** the user runs “Format Document”.
* **Then** the server returns deterministic edits that normalize block layout (`@imports`, `@states`, `@transitions`, comments, alignment).
* **Given** a `.urkel` file in VS Code.
* **When** semantic highlighting is enabled.
* **Then** the server publishes semantic tokens that distinguish machine names, states, events, directives (`@states`, `@transitions`, etc.), and type payloads.
* **Given** the cursor is in a states or transitions block, including a partially typed line.
* **When** completion is requested.
* **Then** the server suggests structural snippets, grammar keywords, and known state/event symbols from the current document without requiring the file to parse perfectly.
* **Given** diagnostics indicate common fixable issues (e.g., missing `init` state, unresolved target state typo candidates).
* **When** code actions are requested.
* **Then** the server returns quick fixes where safe (insert `init` scaffold, replace with nearest known state name).
* **Given** the cursor hovers over a state/event/directive.
* **When** hover is requested.
* **Then** the server returns concise documentation (kind, usage, and constraints from grammar/validator rules).

## 4. Implementation Details
* **AST Range Upgrade (Dependency):** Update the `MachineAST` and the `UrkelParser` (US-2.2) to capture and store Source Ranges (Line/Column offsets) for every node. The LSP relies entirely on knowing exactly *where* tokens live in the text.
* Add LSP capabilities to the server:
  * `documentFormattingProvider`
  * `semanticTokensProvider`
  * `completionProvider`
  * `codeActionProvider`
  * `hoverProvider`
* **The Formatter:** Leverage Point-Free `swift-parsing`'s bidirectional parsing ("printing") capabilities. Instead of writing a manual formatter, run the AST back through the parser in reverse to "print" a perfectly formatted, idempotent `.urkel` string.
* Semantic token legend baseline:
  * token types: `keyword`, `type`, `function`, `enumMember`, `variable`, `namespace`
  * token modifiers as needed (e.g. `declaration`, `readonly`)
* Implement completion sources:
  * static grammar snippets
  * dynamic symbols from the current AST (states, events, factory params)
  * partial-document fallbacks so completions stay useful while a transition is still being written
* Implement safe quick-fix actions only; avoid speculative rewrites.

## 5. Testing Strategy
* **Formatter tests:** golden/inline snapshot tests proving deterministic and idempotent edits via bidirectional parsing.
* **Semantic token tests:** unit tests on token extraction and stable ordering for a fixture file (using the newly added AST Source Ranges).
* **Completion tests:** verify context-sensitive suggestions in `@states` and `@transitions` sections, including partially written lines and the presence of both grammar keywords and current-document symbols.
* **Code action tests:** ensure quick-fix edits are correct and only emitted when safe.
* **End-to-end stdio tests:** initialize -> open/change -> request formatting/tokens/completion/actions.

## 6. Out of Scope
* Rename symbol across workspace.
* Full refactoring engine.
* Multi-file dependency graph analysis.

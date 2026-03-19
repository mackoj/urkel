# US-2.3: AST Source Range Tracking & Bidirectional Printing

## 1. Objective
Enhance the `swift-parsing` engine to capture exact line and column offsets for every node in the `MachineAST`, and implement bidirectional parsing (printing) to enable zero-cost auto-formatting.

## 2. Context
While US-2.2 successfully builds the in-memory AST using `swift-parsing`, the Language Server (Epic 6) needs to know *exactly* where those tokens live in the text file to draw error squiggles and semantic highlighting. Furthermore, one of the greatest superpowers of `swift-parsing` is that parsers can also act as "Printers". By explicitly designing our combinators to be bidirectional, we get a world-class code formatter for `.urkel` files entirely for free.

## 3. Acceptance Criteria
* **Given** a parsed `MachineAST`.
* **When** inspecting a `StateNode` or `TransitionNode`.
* **Then** the node contains a `SourceRange` property indicating its exact start/end line and column offsets in the original `.urkel` file.
* **Given** a malformed text file that triggers a parser error.
* **When** the error is caught.
* **Then** the error explicitly contains the exact line and column of the syntax failure.
* **Given** a valid, programmatically constructed `MachineAST` (or a messy one that was just parsed).
* **When** the `UrkelParser.print(ast:)` method is called.
* **Then** it runs the parsers in reverse and outputs a perfectly formatted, standardized `.urkel` string.

## 4. Implementation Details
* **AST Updates:** Update all structs in `MachineAST` to include an optional `range: SourceRange?` property (where `SourceRange` is a simple struct holding `start` and `end` indices/lines).
* **Range Tracking:** Wrap the core `swift-parsing` combinators with a custom tracker that captures the `Substring` bounds before and after a rule succeeds, mapping those bounds to line/column coordinates.
* **Bidirectional Printing:** Ensure that the combinators built in US-2.2 conform to the `ParserPrinter` protocol. 
* Implement strict whitespace printing rules (e.g., forcing standard indentation on the `@transitions` block when printing, even if the user wrote it with weird spacing).

## 5. Testing Strategy
* **Location Tests:** Parse a hardcoded string `\n\n@states\n  init Idle`. Assert that the `Idle` state node reports its location exactly at Line 4, Column 8.
* **Formatting (Round-Trip) Tests:** 1. Take a terribly formatted `.urkel` string (extra spaces, weird tabs).
  2. Parse it into an AST.
  3. Print the AST back to a string.
  4. Assert the resulting string is perfectly indented and matches a "golden" formatted snapshot.
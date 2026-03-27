# US-10.2: Full Swift Context Types in `machine` Declaration

## 1. Objective
Allow `machine Name<ContextType>` to accept full Swift type syntax (generics, optionals, nested types), not only simple identifiers.

## 2. Context
The parser currently accepts only identifier-like context types in the machine declaration. This limits expressiveness and makes the grammar inconsistent with payload type flexibility already supported in transition parameters.

## 3. Acceptance Criteria
* **Given** `machine Example<MyContext>`.
* **When** parsed.
* **Then** behavior remains unchanged.

* **Given** `machine Example<Result<MyState, Error>>` or `machine Example<MyModule.Context?>`.
* **When** parsed.
* **Then** parsing succeeds and `contextType` preserves the full Swift type text.

* **Given** malformed context delimiters.
* **When** parsed.
* **Then** parser returns actionable line/column diagnostics.

## 4. Implementation Details
* Replace identifier-only parsing for machine context with balanced-delimiter parsing similar to parameter type parsing.
* Keep AST as source-of-truth string for context type to avoid speculative normalization.
* Update language spec docs with advanced context examples.

## 5. Testing Strategy
* Add parser tests for nested generic context types and optional context types.
* Add negative tests for malformed angle-bracket context declarations.

# US-10.3: Richer Semantic Validation Rules

## 1. Objective
Expand validator guarantees beyond initial-state presence and state reference existence to catch more modeling issues early.

## 2. Context
Current validation is intentionally minimal. As usage grows, teams benefit from stronger semantic checks (duplicate state names, duplicate transition signatures from same source, unreachable states, and optional policy checks for terminal-state exits).

## 3. Acceptance Criteria
* **Given** duplicate state names in `@states`.
* **When** validated.
* **Then** validation fails with clear diagnostics.

* **Given** duplicate transitions with same source + event signature + destination.
* **When** validated.
* **Then** validation fails and reports duplicates.

* **Given** states unreachable from the initial state.
* **When** validated.
* **Then** validator reports unreachable states (error or warning policy documented).

* **Given** a terminal state with outgoing transitions.
* **When** validated.
* **Then** validator reports violation if strict terminal semantics are enabled.

## 4. Implementation Details
* Introduce additional `UrkelValidationError` cases with state/event context.
* Keep deterministic ordering for diagnostics.
* Define policy boundaries (hard errors vs optional warnings) and document defaults.

## 5. Testing Strategy
* Unit tests for each new semantic rule.
* LSP diagnostic tests should verify new validator errors map to ranges and messages.

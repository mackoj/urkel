# US-16.1: Formal Property Verification (`@assert`)

## 1. Objective

Extend the `.urkel` DSL with an `@assert` block that lets developers declare **machine-level properties** — invariants about reachability, unreachability, path length, and transition existence — which are verified statically at compile time by the Urkel validator and reported as build errors or warnings.

## 2. Context

Urkel's static graph is fully known at parse time, which means it is possible to verify properties about the machine without executing any code. This is something XState fundamentally cannot do — XState's machines are runtime objects.

Formal verification for FSMs is a well-studied field (model checking, reachability analysis, LTL/CTL specifications). Urkel doesn't need to implement a full model checker, but a pragmatic subset of assertions covering the most common correctness properties would be uniquely valuable:

- "Every path through this machine eventually reaches `Stopped`" (liveness)
- "The machine can never go from `Error` back to `Idle`" (safety)
- "No state has more than N outgoing transitions" (complexity budget)
- "All states are reachable from `init`" (completeness)

These assertions are declared in the `.urkel` file itself, travel with the machine definition, and are checked by the validator on every build — not just when a developer manually runs a lint tool.

## 3. Acceptance Criteria

* **Given** an `@assert alwaysReaches: Stopped` declaration, **when** the validator runs, **then** it verifies that every simple path from `init` eventually reaches a `final` state (specifically `Stopped` if named), and emits a build error if any path terminates without reaching it.

* **Given** an `@assert neverReaches: Idle from: Error` declaration, **when** the validator runs, **then** it verifies that no path from `Error` can reach `Idle`, and emits an error if such a path exists.

* **Given** an `@assert allStatesReachable` declaration (or enabled by default in strict mode), **when** the validator runs, **then** it verifies every non-`init` state has at least one incoming path from `init`, emitting a warning for unreachable states.

* **Given** an `@assert maxDepth: 10` declaration, **when** the validator runs, **then** it verifies that no simple path from `init` to any `final` state exceeds 10 transitions, and emits an error if one does.

* **Given** an `@assert eventAlwaysAvailable: stop` declaration, **when** the validator runs, **then** it verifies that every non-final state has a `stop` transition (directly or via wildcard), emitting an error for any state that does not.

* **Given** all assertions pass, **when** the build runs, **then** no additional output is produced — assertions are silent on success.

* **Given** an assertion fails, **when** the error is reported, **then** the error message includes the assertion name, the failing state/path, and a human-readable explanation.

## 4. Implementation Details

* **DSL syntax** — `@assert` block after `@transitions`:
  ```
  @assert
    alwaysReaches: Stopped
    neverReaches: Idle from: Error
    allStatesReachable
    maxDepth: 15
    eventAlwaysAvailable: stop
    eventAlwaysAvailable: networkLost
  ```

* **grammar.ebnf — add `AssertBlock`:**
  ```ebnf
  AssertBlock    ::= "@assert" Newline (Indent AssertDecl+ Dedent)
  AssertDecl     ::= AlwaysReachesAssert | NeverReachesAssert
                   | AllReachableAssert  | MaxDepthAssert
                   | EventAvailableAssert
  AlwaysReachesAssert   ::= "alwaysReaches" ":" Identifier
  NeverReachesAssert    ::= "neverReaches" ":" Identifier "from" ":" Identifier
  AllReachableAssert    ::= "allStatesReachable"
  MaxDepthAssert        ::= "maxDepth" ":" IntLiteral
  EventAvailableAssert  ::= "eventAlwaysAvailable" ":" Identifier
  ```

* **AST** — new `AssertBlockNode` containing `[AssertNode]`. `AssertNode` is an enum with associated values per assertion type.

* **Validator (`UrkelValidator.swift`)** — new `AssertionChecker` struct that accepts the machine's `GraphModel` (from `GraphAnalyzer`, US-13.3) and evaluates each assertion:
  - `alwaysReaches` → verify all paths from `init` reach target (DFS, collect terminating states)
  - `neverReaches` → verify no path exists from `from` state to target (BFS with visited set)
  - `allStatesReachable` → standard reachability from `init`
  - `maxDepth` → longest shortest path (BFS, report if any path exceeds limit)
  - `eventAlwaysAvailable` → check each non-final state has outgoing transition with the given event name (or a wildcard covers it)

* **Error reporting** — assertions produce `UrkelDiagnostic` values (same type used for parse/semantic errors) so they appear inline in VS Code via the LSP.

* **Strict mode** — `urkel-config.json` can enable `"strictAssertions": true` which implicitly adds `allStatesReachable` and requires at least one `final` state even without an explicit `@assert` block.

## 5. Testing Strategy

* Parser: all five assertion types parse correctly; unknown assertion keyword → warning (not error, for forward compatibility).
* Validator — `alwaysReaches`: machine where one path doesn't reach final → error; all paths reach final → pass.
* Validator — `neverReaches`: path exists between forbidden states → error; no path → pass.
* Validator — `allStatesReachable`: unreachable state present → warning.
* Validator — `maxDepth`: path of length 11 with `maxDepth: 10` → error.
* Validator — `eventAlwaysAvailable`: state missing the required event → error; wildcard covers it → pass.
* Integration: add `@assert` block to `BluetoothScale/scale.urkel` example; verify all assertions pass.
* Regression: none of the existing example `.urkel` files should gain new errors when `allStatesReachable` is added as a default warning.

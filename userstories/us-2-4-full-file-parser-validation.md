# US-2.4: Full File Parser & Semantic Validation

## Objective

Assemble the primitive and block-level parsers (US-2.1–3.3) into a single
`UrkelParser` that parses a complete `.urkel` file into a `UrkelFile` AST, then
run a structured semantic validation pass that catches logical errors in the
graph before any code is generated. Both parse errors and validation diagnostics
carry `SourceRange` locations.

## Background

Syntax correctness (the parser's job) is necessary but not sufficient. A file
can be syntactically valid yet semantically broken — referencing a state that
was never declared, omitting a required `init`, or leaving a `final` state
unreachable. Emitting code from such a file produces confusing Swift compiler
errors far from the true source. The validator catches these at the Urkel layer
with precise, actionable messages.

The validator is a multi-pass walk over the `UrkelFile` AST. Each pass is
independent and produces `[Diagnostic]` — structured errors or warnings, never
exceptions. The caller decides whether to abort on errors or collect them all.

## Grammar Productions Covered (file level)

```ebnf
UrkelFile    ::= { TriviaLine }
                 MachineDecl
                 { TriviaLine }
                 { ImportDecl TriviaLine* }
                 { ParallelDecl TriviaLine* }
                 StatesBlock
                 { TriviaLine }
                 { EntryExitDecl TriviaLine* }
                 TransitionsBlock
                 { TriviaLine }

MachineDecl  ::= { Whitespace } "machine" Whitespace Identifier
                 [ { Whitespace } ":" { Whitespace } Identifier ]
                 { Whitespace } Newline

ImportDecl   ::= { Whitespace } "@import" Whitespace Identifier
                 [ { Whitespace } "from" { Whitespace } Identifier ]
                 { Whitespace } Newline

ParallelDecl ::= { Whitespace } "@parallel" Whitespace Identifier
                 { Whitespace } Newline
                 { TriviaLine | RegionDecl }

RegionDecl   ::= { Whitespace } "region" Whitespace Identifier
                 { Whitespace } Newline
                 StatesBlock
                 TransitionsBlock

EntryExitDecl ::= { Whitespace } ( "@entry" | "@exit" )
                  Whitespace StateRef
                  { Whitespace } "/" { Whitespace } ActionList
                  { Whitespace } Newline
```

## Public API

```swift
public struct UrkelParser {
  /// Parse a `.urkel` source string into a `UrkelFile` AST.
  /// Throws `ParseError` on syntax failure.
  public static func parse(_ source: String) throws -> UrkelFile

  /// Validate a `UrkelFile` AST. Returns all diagnostics (errors and warnings).
  /// The machine is considered valid when no `.error`-severity diagnostics are present.
  public static func validate(_ file: UrkelFile) -> [Diagnostic]
}

public struct Diagnostic: Sendable {
  public enum Severity { case error, warning }
  public var severity: Severity
  public var code: DiagnosticCode
  public var message: String
  public var range: SourceRange?
}

public enum DiagnosticCode: String, Sendable {
  // Init / final rules
  case missingInitState           // no `init` state declared
  case multipleInitStates         // more than one `init` state
  case missingFinalState          // no `final` state declared (warning by default)
  // State reference integrity
  case undefinedStateReference    // transition from/to an undeclared state
  case undefinedEntryExitState    // @entry/@exit references undeclared state
  case undefinedReactiveState     // @on references unknown sub-machine or region
  case duplicateStateName         // two states share a name in the same scope
  // Graph health
  case unreachableState           // no path from init to this state (warning)
  case deadState                  // non-final state with no outgoing transitions (warning)
  // Guard ordering
  case elseGuardNotLast           // [else] is not the last branch for (source, event)
  case duplicateGuardBranch       // same guard name appears twice for (source, event)
  // @history placement
  case historyOnNonCompoundState  // @history on a state outside a compound block
  // Fork integrity
  case undeclaredImportInFork     // `=> Sub.init` with no `@import Sub`
  case unknownForkBinding         // binding source name not on event or source state params
  // State-carried data (US-1.19)
  case missingRequiredStateParam  // inbound transition doesn't supply a required state param
  case missingTimerParams         // after() dest state requires params not on TimerDecl
  // Parallel region integrity
  case regionMissingInit          // a parallel region has no `init` state
  case regionMissingFinal         // a parallel region has no `final` state (warning)
}
```

## Acceptance Criteria

### Parser

* **Given** the full text of `FolderWatch/Sources/FolderWatch/folderwatch.urkel`,
  **when** `UrkelParser.parse(_:)` is called, **then** it returns a `UrkelFile`
  equal to the reference fixture from US-2.2.

* **Given** a syntactically malformed file (e.g. `"Idle -> start ->"` with no
  destination), **when** parsed, **then** it throws a `ParseError` containing
  the line and column of the failure.

* **Given** a file that uses v1-deprecated syntax (`@factory`, `@compose`, or
  `machine Name<Context>`), **when** parsed, **then** the parser fails with a
  dedicated `ParseError` that names the deprecated construct and suggests the v2
  replacement.

### Validator

* **Given** an AST with no `init` state, **when** validated, **then**
  `diagnostics` contains exactly one `.error` with code `.missingInitState`.

* **Given** an AST with two `init` states, **when** validated, **then**
  `.multipleInitStates` error is present.

* **Given** a transition `Idle -> go -> Runningg` where `"Runningg"` is not in
  `@states`, **when** validated, **then** `.undefinedStateReference` error is
  present with `range` pointing to `"Runningg"` in the source.

* **Given** a machine where `StateB` has no inbound transitions from `init` and
  no path from `init` reaches it, **when** validated, **then** a `.warning` with
  code `.unreachableState` is emitted for `StateB`.

* **Given** a non-final state with no outgoing transitions, **when** validated,
  **then** a `.warning` with code `.deadState` is emitted.

* **Given** `[else]` is not the last guard clause on the same `(source, event)`
  group, **when** validated, **then** `.elseGuardNotLast` error is present.

* **Given** `=> Sub.init` in a transition but no `@import Sub` at the file level,
  **when** validated, **then** `.undeclaredImportInFork` error is present.

* **Given** `state Loaded(data: Data)` and `Loading -> fetchSuccess -> Loaded`
  (no params on event, but `Loaded` requires `data`), **when** validated,
  **then** `.missingRequiredStateParam` error is present.

* **Given** a BYOT parameter `device: Result<CBPeripheral, BluetoothError>`,
  **when** validated, **then** the validator does **not** attempt to resolve the
  type expression — BYOT boundary is respected.

## Implementation Details

* Create `Sources/Urkel/Parser/UrkelParser.swift` — the public entry point.
* Create `Sources/Urkel/Parser/UrkelFileParser.swift` — the top-level
  `swift-parsing` combinator combining all block parsers in grammar order.
* Create `Sources/Urkel/Validation/Diagnostic.swift` and
  `Sources/Urkel/Validation/DiagnosticCode.swift`.
* Create `Sources/Urkel/Validation/UrkelValidator.swift` — each diagnostic code
  is implemented as a separate private method; the public `validate` method calls
  them all and returns the union of results.
* Validation passes:
  1. Build a flat `Set<String>` of all declared state names (per scope).
  2. Init/final count check per scope (machine root + each parallel region).
  3. Reference resolution (transitions, @entry/@exit, @on, fork).
  4. Duplicate state name detection per scope.
  5. Guard ordering validation per `(source, event)` group.
  6. @history placement: allowed only inside compound state children.
  7. Fork `@import` presence.
  8. State-carried data param supply (per US-1.19 rules).
  9. Reachability BFS from `init` → unreachable states.
  10. Dead state detection (out-degree == 0, not `final`).

## Testing Strategy

* Create `Tests/UrkelTests/ParserTests/UrkelParserTests.swift` — end-to-end
  parse tests for all example `.urkel` files.
* Create `Tests/UrkelTests/ValidationTests/UrkelValidatorTests.swift` — one test
  per `DiagnosticCode`, constructing minimal ASTs that trigger exactly that code.
* Construct a deliberately invalid `.urkel` file covering 5+ error codes
  simultaneously; assert the full diagnostics array without order dependency.
* Parse → validate round-trip on all examples: assert zero `.error` diagnostics
  on every shipped example file.

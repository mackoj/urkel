# US-2.3: Transitions Block Parsers

## Objective

Implement the `swift-parsing` combinators for every form of transition and
reactive statement: standard and internal arrows, event declarations, timer
declarations, guard clauses, action clauses, fork clauses, eventless (`always`)
transitions, and `@on` reactive statements. Together these parsers cover the
most syntactically complex section of any `.urkel` file.

## Background

The `@transitions` block contains two interleaved statement kinds:
`TransitionStmt` (caller-driven) and `ReactiveStmt` (`@on`, child-driven). Both
share sub-parsers for arrows, guards, and actions but diverge on their source
and destination grammar.

Transition statements carry the most modifier combinations of any grammar rule:
a single line can include a source, two arrows, an event with params, a guard, a
destination, a fork with bindings, and an action list. Parsing order must follow
the grammar precisely to avoid ambiguity — this story documents both the grammar
and the combinator structure in parallel.

## Grammar Productions Covered

```ebnf
TransitionsBlock ::= { Whitespace } "@transitions" { Whitespace } Newline
                     { TriviaLine | TransitionStmt | ReactiveStmt }

TransitionStmt   ::= { Whitespace } TransitionSource
                     { Whitespace } Arrow { Whitespace }
                     EventOrTimer
                     [ { Whitespace } GuardClause ]
                     [ { Whitespace } Arrow { Whitespace } StateRef
                       [ { Whitespace } ForkClause ] ]
                     [ { Whitespace } ActionClause ]
                     { Whitespace } Newline

TransitionSource ::= StateRef | "*"
Arrow            ::= "->" | "-*>"
EventOrTimer     ::= EventDecl | TimerDecl | "always"
EventDecl        ::= Identifier [ "(" ParameterList ")" ]
TimerDecl        ::= "after" "(" Duration [ "," ParameterList ] ")"
Duration         ::= Number DurationUnit
DurationUnit     ::= "ms" | "s" | "min"
GuardClause      ::= "[" { Whitespace } GuardExpr { Whitespace } "]"
GuardExpr        ::= "else" | "!"? Identifier
ActionClause     ::= "/" { Whitespace } ActionList
ActionList       ::= Identifier { { Whitespace } "," { Whitespace } Identifier }
ForkClause       ::= "=>" { Whitespace } Identifier ".init"
                     [ "(" ForkBindingList ")" ]
ForkBindingList  ::= ForkBinding { "," ForkBinding }
ForkBinding      ::= Identifier ":" Identifier

ReactiveStmt     ::= { Whitespace } "@on" Whitespace ReactiveSource
                     [ { Whitespace } "," { Whitespace } Identifier ]
                     { Whitespace } Arrow { Whitespace }
                     ( StateRef [ ActionClause ] | ActionClause )
                     { Whitespace } Newline

ReactiveSource   ::= ReactiveTarget "::" ReactiveState
ReactiveTarget   ::= Identifier | Identifier "." Identifier
ReactiveState    ::= Identifier | "init" | "final" | "*"
StateRef         ::= Identifier { "." Identifier }
```

## Acceptance Criteria

* **Given** `"  Idle -> start -> Running\n"`, **when** parsed,
  **then** `source == .state(["Idle"])`, `arrow == .standard`,
  `event == .event(EventDecl(name: "start", params: []))`,
  `destination == StateRef(["Running"])`.

* **Given** `"  Loading -*> progress(percent: Double)\n"` (output event, no action),
  **when** parsed, **then** `arrow == .internal`, `destination == nil`,
  `action == nil`.

* **Given** `"  Loading -*> progress(percent: Double) / notify\n"` (in-place handler),
  **when** parsed, **then** `action == ActionClause(actions: ["notify"])`.

* **Given** `"  Idle -> after(30s, code: Int) [timeout] -> Error\n"`,
  **when** parsed, **then** `event == .timer(TimerDecl(duration: Duration(30, .s), params: [Parameter("code", "Int")]))`,
  `guard == .named("timeout")`.

* **Given** `"  * -> cancel -> Cancelled\n"`, **when** parsed,
  **then** `source == .wildcard`.

* **Given** `"  Idle -> always [hasData] -> Loaded\n"`, **when** parsed,
  **then** `event == .always`, `guard == .named("hasData")`.

* **Given** `"  Idle -> always [else] -> Error\n"`, **when** parsed,
  **then** `guard == .else`.

* **Given** `"  Connecting -> deviceFound(device: CBPeripheral) -> Connected => Scanner.init(peripheral: device)\n"`,
  **when** parsed, **then** `fork == ForkClause(machine: "Scanner", bindings: [ForkBinding(param: "peripheral", source: "device")])`.

* **Given** `"  @on Scanner::final -> Done / cleanup\n"`, **when** parsed,
  **then** a `ReactiveStmt` with `source.target == .machine("Scanner")`,
  `source.state == .final`, `destination == StateRef(["Done"])`,
  `action == ActionClause(["cleanup"])`.

* **Given** `"  @on Playback.Audio::Buffering, Idle -> Loading\n"`,
  **when** parsed, **then** `source.target == .region("Playback", "Audio")`,
  `ownState == "Idle"`.

* **Given** a full `@transitions` block mixing trivia, standard transitions,
  internal transitions, reactive statements, and doc comments, **when** parsed,
  **then** all nodes are in order and `docComments` are attached to the
  immediately following statement.

## Implementation Details

* Create `Sources/Urkel/Parser/Transitions/`:
  - `ArrowParser.swift`
  - `EventDeclParser.swift` — identifier + optional `( ParameterList )`.
  - `TimerDeclParser.swift` — `after(Duration[, ParameterList])`.
  - `DurationParser.swift` — number literal + unit keyword.
  - `GuardClauseParser.swift`
  - `ActionClauseParser.swift`
  - `ForkClauseParser.swift`
  - `StateRefParser.swift` — dot-joined identifiers.
  - `TransitionSourceParser.swift` — `StateRef | "*"`.
  - `TransitionStmtParser.swift` — full combinator assembling all optional parts
    in grammar order.
  - `ReactiveSourceParser.swift`
  - `ReactiveStmtParser.swift`
  - `TransitionsBlockParser.swift` — header + repeated `TriviaLine | TransitionStmt | ReactiveStmt`.
* The distinction between an output event declaration (`-*>` no action) and an
  in-place handler (`-*>` with action) is preserved in the AST (presence of
  `action`); the parser does not need to disambiguate — the validator does.
* Source-range attachment follows the same `WithRange` helper pattern from US-2.2.

## Testing Strategy

* Create `Tests/UrkelTests/ParserTests/TransitionsBlockTests.swift`.
* Test each sub-parser in isolation, then compose:
  - `DurationParser` — `"30s"`, `"500ms"`, `"2min"`, `"1.5s"`.
  - `GuardClauseParser` — `[guard]`, `[!guard]`, `[else]`.
  - `ForkClauseParser` — no bindings, one binding, multiple bindings.
  - `TransitionStmtParser` — all combinations of optional clauses.
  - `ReactiveStmtParser` — machine source, region source, `ownState` present/absent.
* Parse the full `@transitions` block from `FolderWatch` and `BluetoothBlender`
  examples; assert against reference fixtures from US-2.2.
* Confirm that source ranges are populated on all returned nodes.

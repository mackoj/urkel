# US-3.2: Extended AST Nodes

## Objective

Complete the AST model by defining all advanced node types introduced by the v2
grammar: compound states, parallel regions with their inner machines, full
transition statements (guards, actions, timers, forks), reactive statements
(`@on`), entry/exit lifecycle hooks, and all their modifier types.

## Background

The v2 grammar introduced a substantial surface area beyond flat state machines:

- **Compound states** (`state Name { … }`) — hierarchical sub-state spaces with
  their own inner transitions.
- **Parallel regions** (`@parallel Name { region … }`) — orthogonal concurrency
  without sub-processes.
- **Entry/exit hooks** (`@entry`/`@exit`) — lifecycle actions declared outside
  the transitions block.
- **Full transition modifiers** — guards (`[name]`, `[!name]`, `[else]`), actions
  (`/ a, b`), forks (`=> Sub.init(bindings…)`), timers (`after(Ns)`), eventless
  (`always`), internal/output arrows (`-*>`).
- **Reactive statements** (`@on Sub::State -> Dest / action`) — parent reactions
  to child machine or parallel region state changes.

All of these were placeholders in US-3.1. This story replaces those placeholders
with fully typed, `Equatable` Swift types.

## AST Nodes (this story)

### States

```
StateDecl = .simple(SimpleStateDecl) | .compound(CompoundStateDecl)

SimpleStateDecl
  kind: StateKind               # .init | .state | .final
  params: [Parameter]           # may be empty
  name: String
  history: HistoryModifier?
  docComments: [DocComment]

StateKind = .`init` | .state | .final

HistoryModifier = .shallow | .deep   # @history vs @history(deep)

CompoundStateDecl
  name: String
  history: HistoryModifier?
  children: [SimpleStateDecl]   # inner @states
  innerTransitions: [TransitionStmt]
  docComments: [DocComment]
```

### Parallel

```
ParallelDecl
  name: String
  regions: [RegionDecl]
  docComments: [DocComment]

RegionDecl
  name: String
  states: [StateDecl]
  transitions: [TransitionStmt]
```

### Entry / Exit Hooks

```
EntryExitDecl
  hook: HookKind                # .entry | .exit
  state: StateRef               # dot-qualified: "Active.Playing"
  actions: [String]             # action identifiers

HookKind = .entry | .exit
```

### Transitions

```
TransitionStmt
  source: TransitionSource      # .state(StateRef) | .wildcard
  arrow: Arrow                  # .standard | .internal
  event: EventOrTimer
  guard: GuardClause?
  destination: StateRef?        # nil on ->> without dest
  fork: ForkClause?
  action: ActionClause?
  docComments: [DocComment]

TransitionSource = .state(StateRef) | .wildcard

Arrow = .standard | .internal   # "->" vs "-*>"

EventOrTimer
  = .event(EventDecl)
  | .timer(TimerDecl)
  | .always

EventDecl
  name: String
  params: [Parameter]

TimerDecl
  duration: Duration
  params: [Parameter]           # forwarded to dest state (GAP-7)

Duration
  value: Double
  unit: DurationUnit            # .ms | .s | .min

GuardClause
  = .named(String)              # [guardName]
  | .negated(String)            # [!guardName]
  | .else                       # [else]

ActionClause
  actions: [String]             # / a, b, c

ForkClause
  machine: String               # "Sub" in "=> Sub.init"
  bindings: [ForkBinding]       # may be empty

ForkBinding
  param: String                 # dest init param name
  source: String                # source name (event param or state param)
```

### Reactive Statements

```
ReactiveStmt
  source: ReactiveSource
  ownState: String?             # optional ", OwnState" AND condition
  arrow: Arrow
  destination: StateRef?
  action: ActionClause?
  docComments: [DocComment]

ReactiveSource
  target: ReactiveTarget
  state: ReactiveState

ReactiveTarget
  = .machine(String)                    # "Sub"
  | .region(parallel: String, region: String)  # "P.RegionA"

ReactiveState
  = .named(String)
  | .`init`
  | .final
  | .any                               # "*"
```

### Shared

```
StateRef
  components: [String]          # ["Active", "Playing"] for "Active.Playing"
  (convenience: var name: String { components.joined(separator: ".") })

TransitionDecl = .transition(TransitionStmt) | .reactive(ReactiveStmt)
```

## Acceptance Criteria

* **Given** a `TransitionStmt` with `arrow: .internal`, **when** compared to an
  identical one, **then** `==` returns `true`; changing the arrow to `.standard`
  makes `==` return `false`.

* **Given** a `CompoundStateDecl` containing two `SimpleStateDecl` children and
  one inner `TransitionStmt`, **when** two identical instances are compared,
  **then** `==` returns `true`.

* **Given** a `TimerDecl(duration: Duration(value: 30, unit: .s), params: [Parameter(label: "code", typeExpr: "Int")])`,
  **when** constructed, **then** it compiles and its `params` count equals `1`.

* **Given** a `ReactiveStmt` with `.region(parallel: "Playback", region: "Audio")`
  target and `.named("Buffering")` state, **when** constructed and compared,
  **then** equality holds for identical instances and fails for differing targets.

* **Given** all node types in US-3.1 and US-3.2 together, **when** a `UrkelFile`
  is fully populated with every node kind, **then** it compiles and `==` works
  recursively across the entire tree.

* **Given** all types in this story, **when** compiled, **then** every type
  conforms to `Equatable`, `Sendable`, and `Codable`.

## Implementation Details

* Replace `Sources/Urkel/AST/Placeholders.swift` with the full implementations:
  - `Sources/Urkel/AST/StateDecl.swift` — `StateDecl`, `SimpleStateDecl`,
    `CompoundStateDecl`, `StateKind`, `HistoryModifier`
  - `Sources/Urkel/AST/ParallelDecl.swift` — `ParallelDecl`, `RegionDecl`
  - `Sources/Urkel/AST/EntryExitDecl.swift`
  - `Sources/Urkel/AST/TransitionStmt.swift` — `TransitionStmt`, `TransitionSource`,
    `Arrow`, `EventOrTimer`, `EventDecl`, `TimerDecl`, `Duration`, `DurationUnit`,
    `GuardClause`, `ActionClause`, `ForkClause`, `ForkBinding`
  - `Sources/Urkel/AST/ReactiveStmt.swift` — `ReactiveStmt`, `ReactiveSource`,
    `ReactiveTarget`, `ReactiveState`
  - `Sources/Urkel/AST/Shared.swift` — `StateRef`, `TransitionDecl`
* All types under `public` access.
* No logic, no parsing, no validation — pure data.

## Testing Strategy

* Extend `Tests/UrkelTests/ASTTests/` with one test file per major group:
  `StateDeclTests`, `TransitionStmtTests`, `ReactiveStmtTests`.
* For each node kind, construct two identical instances and assert `==`; mutate
  one field and assert `!=`.
* Build the complete `UrkelFile` AST for the `BluetoothBlender` example by hand
  (compound states, parallel region, @on reactive, fork) and assert it equals a
  second hand-built instance. This becomes the **reference fixture** used to
  verify the parser in Epic 3.

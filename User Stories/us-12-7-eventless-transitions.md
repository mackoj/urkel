# US-12.7: Eventless / Automatic Transitions (`always`)

## 1. Objective

Extend the `.urkel` DSL to support **eventless transitions** — transitions that fire automatically when a state is entered if their guard condition is true, requiring no explicit event from the caller.

## 2. Context

Eventless transitions (also called "always" or "automatic" transitions) model conditions that should be evaluated immediately on state entry. They are distinct from guards on regular transitions: a guard prevents a transition from firing; an `always` transition fires on its own if the condition is met.

They are essential for two patterns:

1. **Conditional routing** — entering a state that immediately branches to one of several other states based on the current context. The routing state is never "visible" to the caller (it's transient).

2. **Reactive re-evaluation** — a state that should continuously evaluate a condition and transition as soon as it becomes true (e.g., a heating element that transitions to `Boiling` as soon as temperature > 100°C, whenever that happens).

XState uses `always: [{ guard: '...', target: '...' }]` as a key on state nodes. Urkel uses `always` as a **keyword in the event position** of the standard transition arrow syntax, keeping the flat table structure intact.

An unguarded `always` transition makes the state **transient** — it is entered and immediately exited. This is useful for pure routing/branch states.

## 3. Acceptance Criteria

* **Given** `Cart -> always [isLoggedIn] -> Payment`, **when** the machine enters `Cart` and `isLoggedIn` returns `true`, **then** the machine immediately and automatically transitions to `Payment` without any event being sent.

* **Given** `Cart -> always [isLoggedIn] -> Payment`, **when** `isLoggedIn` returns `false` on entry, **then** the machine stays in `Cart` and waits for an explicit event as normal.

* **Given** multiple `always` transitions on the same state, **when** the state is entered, **then** they are evaluated in declaration order and the first whose guard is true is taken.

* **Given** an unguarded `always` transition (`Routing -> always -> TargetState`), **when** the state is entered, **then** it immediately transitions to the target — making `Routing` a transient state.

* **Given** an unguarded `always` with no target (`always /action`), **when** the state is entered, **then** the action fires but the state does not change (useful for reactive side effects on entry without re-entering).

* **Given** an `always` transition with no guard and no target, **when** the validator runs, **then** it emits an error: `"Eventless transition must have a guard, a target, or both"` (prevents infinite loops).

* **Given** a transient state that is only entered and exited via `always`, **when** the Simulate mode runs, **then** the state is shown as a brief flash/pass-through in the simulation timeline, not as a stable resting state.

* **Given** a machine with `always` transitions and the path explorer (US-13.3), **when** `--all-paths` is run, **then** eventless branches are correctly enumerated as path steps.

## 4. Implementation Details

* **DSL syntax:**
  ```
  @transitions
    # Conditional routing on entry (guard required)
    Cart       -> always [isLoggedIn]        -> Payment

    # Multiple ordered always on same state
    Validating -> always [isValid]           -> Submitting
    Validating -> always [!isValid]          -> Invalid

    # Transient routing state (unguarded — always fires)
    Routing    -> always                     -> Dashboard

    # Reactive with action but no state change
    Active    -*> always [isExpired]         / notifyExpiry
  ```
  Note: `always` is a reserved event keyword. It cannot be used as a user-defined event name.

* **grammar.ebnf — extend `EventDecl`:**
  ```ebnf
  EventDecl   ::= Identifier ("(" ParamList ")")? | AfterEvent | AlwaysEvent
  AlwaysEvent ::= "always"
  ```

* **AST** — `TransitionNode` gains `isEventless: Bool`. Eventless transitions with no guard and no target are rejected by the validator.

* **Parser** — detect `always` token in the event position. Since `always` transitions have no parameters, `("(" ParamList ")")` is not valid after `always` — emit a parse error if attempted.

* **Semantic validator:**
  - Error: unguarded `always` transition with no target AND no action.
  - Warning: unguarded `always` transition that creates an obviously infinite loop (target == source and no action).
  - Error: `always` used as a user-defined event name in `@transitions` where no `always` keyword is expected.
  - Warning: state has both `always` and explicit event transitions — the `always` may shadow the explicit events (explain evaluation order).

* **SwiftCodeEmitter** — eventless transitions are evaluated inside the state's entry hook. After any entry actions fire, the emitter inserts guard evaluations in declaration order. The first truthy guard immediately calls the corresponding transition method, short-circuiting the rest. If no guard passes, the machine rests in the state normally.

* **Transient states** — a state whose only outgoing transitions are unguarded `always` is marked `isTransient: true` in the AST. The emitter wraps it so callers never receive a `Machine<TransientState>` value; the transition to the target is immediate and transparent.

## 5. Testing Strategy

* Parser: `always` with guard; `always` without guard; `always` with params → error; `always` as user event name → reserved keyword error.
* Semantic validator: unguarded + no target + no action → error; multiple ordered `always` — correct evaluation order.
* Emitter: guard-true on entry → immediate transition; guard-false on entry → machine rests; transient state → caller never observes it.
* Concurrency: verify `always` evaluation is synchronous and doesn't introduce data races under Swift 6.
* Simulate: transient state shows as pass-through, not stable state.
* Path explorer: `always` branches appear in `--all-paths` output.
* Fixture: `RoutingMachine` (a `Routing` transient state that fans out to `Dashboard` or `Onboarding` based on context) and a `KettleMachine` (reactive `always` for temperature threshold) in `Tests/UrkelTests/Fixtures/`.

# US-1.20: Machine Invariants (`@invariants` block)

## Objective

Allow any machine to declare structural invariants — properties that must hold
over its transition graph — using an optional `@invariants` block at the end of
the `.urkel` file. Invariants are verified statically by `UrkelValidator`
against the AST; they require no runtime and no implementation code.

## Background

The DSL is now complete as a *specification* language. But a spec without
verifiable guarantees is documentation, not a contract. Invariants close that
gap: they let a developer declare — in the same file as the machine — what
must be structurally true about the graph for the machine to be correct.

An invariant is **not a test**. It does not check runtime behaviour. It checks
static graph properties: can a state be reached? Can the machine deadlock?
Is every event routed without ambiguity? These questions are answerable from
the AST alone, at parse time, with no generated code required.

Invariants are co-located with the machine for three reasons:

1. **Single source of truth.** The machine's guarantees live with its structure
   — they appear in the same file, the same PR diff, and the same doc comment
   pass-through. A reader understands both the spec and the contract in one read.

2. **IDE integration.** Because invariants reference state names already in the
   AST, the LSP (Epic 6) can provide completions for state names inside
   invariant expressions and squiggle typos with the same diagnostics that
   the validator produces for the rest of the file.

3. **Visualiser integration.** The visualiser (Epic 4) can overlay invariant
   results on the diagram: a `reachable(State)` that fails turns the node red;
   a `noDeadlock` failure marks the dead state in amber.

### What `reachable(A -> B)` means

`reachable(B)` = "there exists at least one path in the graph from the `init`
state to B, following any sequence of transitions."

`reachable(A -> B)` = "starting from state A, there exists at least one path
to B." This is the **liveness** property: A can eventually lead to B.

`unreachable(B)` and `unreachable(A -> B)` assert the negation. These are most
useful when A is a *cul-de-sac* — a state whose only outgoing transitions lead
exclusively to final states, making all non-final states unreachable from it.
The canonical example is a `LockedOut` state that only leads to `Terminated`:

```
@invariants
  unreachable(LockedOut -> LoggedIn)   ## once locked out, re-auth is impossible
```

For "no direct edge" safety (e.g. "you cannot jump straight from A to B without
going through C"), use a validator rule or a separate `@assert` annotation — not
`unreachable`, whose path-based semantics would be misleading.

## DSL Syntax

```
machine Auth

@states
  …
@transitions
  …

@invariants
  ## Primary success state is always reachable from init
  reachable(LoggedIn)
  ## Token refresh leads back to session or degrades gracefully
  reachable(RefreshingToken -> LoggedIn)
  reachable(RefreshingToken -> LoggedOut)
  ## Safety: locked-out users cannot re-authenticate (they must wait for termination)
  unreachable(LockedOut -> LoggedIn)
  ## All paths terminate — no infinite loop without progress
  allPathsReachFinal
  ## No two unguarded transitions on the same (state, event) pair
  deterministic
```

### Property catalogue

| Expression | Checks |
|-----------|--------|
| `reachable(S)` | S is reachable from `init` by at least one path |
| `reachable(A -> B)` | B is reachable from A by at least one path (liveness) |
| `unreachable(S)` | S is NOT reachable from `init` by any path (safety) |
| `unreachable(A -> B)` | B is NOT reachable from A by any path |
| `noDeadlock` | Every non-final reachable state has ≥ 1 outgoing transition |
| `allPathsReachFinal` | Every reachable non-final state has a path to some `final` state |
| `deterministic` | No (source, event) pair has two unguarded transitions |
| `acyclic` | The transition graph contains no cycles |

**Notes on `acyclic`:** Most long-running machines intentionally cycle (e.g. a
`TrafficLight` loops Red→Green→Yellow→Red forever). `acyclic` is intended for
one-shot pipelines (checkout wizards, file-upload flows) where any cycle
indicates a design error. A cyclic machine MUST NOT declare `acyclic`. A machine
that does not declare `acyclic` may cycle freely.

**Notes on `allPathsReachFinal` vs `noDeadlock`:**
- `noDeadlock` is weaker: it only checks that every state has *some* outgoing
  transition. A state with only a self-loop satisfies `noDeadlock` but might
  never reach a final state.
- `allPathsReachFinal` is stronger: it guarantees that following *some* sequence
  of transitions from any state eventually reaches a `final`. This is the correct
  invariant for machines that are expected to terminate.

### State references in invariants

| Reference form | Meaning |
|----------------|---------|
| `State` | A flat or top-level state name |
| `Compound.Child` | A specific child state inside a compound state |
| `Machine::State` | A state of an `@import`-ed sub-machine |
| `Parallel.Region::State` | A state inside a specific region of an `@parallel` block |

Cross-machine references (`Machine::State`) require the referenced machine to
also have been parsed and validated. The validator resolves them via `@import`
declarations.

### Full example — data fetch with invariants

```
machine DataFetch

@states
  init  Idle
  state Loading
  state Loaded
  state Failed
  final Cancelled

@transitions
  Idle    -> fetch                        -> Loading
  Loading -> success(data: Data)          -> Loaded
  Loading -> failure(error: Error)        -> Failed
  Loading -> after(30s)                   -> Failed
  Loading -> cancel                       -> Cancelled
  Loaded  -> refresh                      -> Loading
  Loaded  -*> data(value: Data)           # output stream
  Failed  -> retry [retriesRemaining]     -> Loading
  Failed  -> retry [else]                 -> Cancelled
  Failed  -*> error(reason: Error)        # output stream
  * -> cancel                             -> Cancelled

@invariants
  ## Every fetch resolves through one of three terminal paths
  reachable(Loading -> Loaded)
  reachable(Loading -> Failed)
  reachable(Loading -> Cancelled)
  ## Bounded retry: the [else] branch guarantees eventual termination
  reachable(Failed -> Cancelled)
  ## Guard pair (retriesRemaining / else) gives exhaustive coverage
  deterministic
  noDeadlock
  allPathsReachFinal
```

### Intentionally cyclic machine — do NOT declare `allPathsReachFinal`

```
machine TrafficLight

@states
  init Red
  state Green
  state Yellow
  final Emergency

@transitions
  Red    -> after(30s) -> Green
  Green  -> after(25s) -> Yellow
  Yellow -> after(5s)  -> Red
  *      -> emergency  -> Emergency

@invariants
  ## All three colours are reachable
  reachable(Green)
  reachable(Yellow)
  ## Emergency stop is always accessible
  reachable(Emergency)
  ## Intentional: this machine cycles — allPathsReachFinal is NOT declared
  noDeadlock
  deterministic
```

## Acceptance Criteria

* **Given** `reachable(LoggedIn)` in an `@invariants` block and `LoggedIn` is
  reachable via at least one transition path from `init`, **when** validated,
  **then** no diagnostic is emitted for that invariant.

* **Given** `reachable(Ghost)` where `Ghost` is not declared in `@states`,
  **when** validated, **then** an `.error` diagnostic is emitted:
  `"invariant references undeclared state 'Ghost'"`.

* **Given** `reachable(Loaded)` but `Loaded` is declared and has no inbound
  transitions from any path from `init`, **when** validated, **then** an `.error`
  diagnostic with code `.invariantViolation` is emitted:
  `"invariant violated: 'Loaded' is not reachable from 'init'"`.

* **Given** `unreachable(LockedOut -> LoggedIn)` and there genuinely is no path
  from `LockedOut` to `LoggedIn` in the graph, **when** validated, **then** no
  diagnostic is emitted.

* **Given** `unreachable(A -> B)` but a path from A to B exists in the graph,
  **when** validated, **then** an `.error` diagnostic is emitted naming the
  violating path for debuggability.

* **Given** `noDeadlock` and a non-final reachable state has zero outgoing
  transitions, **when** validated, **then** `.error` with code
  `.invariantViolation` names the dead state.

* **Given** `allPathsReachFinal` and a reachable non-final state has no path to
  any `final` state (e.g. a cycle with no exit), **when** validated, **then**
  `.error` names the trapped state.

* **Given** `deterministic` and two unguarded transitions share the same
  `(source, event)`, **when** validated, **then** `.error` names the ambiguous pair.

* **Given** `acyclic` and the machine has a cycle, **when** validated, **then**
  `.error` names the first back-edge detected during DFS.

* **Given** `reachable(BLEPeripheral::Connected)` and `@import BLEPeripheral` is
  declared and the imported machine has a `Connected` state, **when** validated,
  **then** the invariant is checked against the imported machine's graph.

* **Given** an `@invariants` block with doc comments (`## …`), **when** printed
  by `UrkelPrinter`, **then** the doc comments appear above their respective
  invariant lines in the output.

* **Given** a machine with no `@invariants` block, **when** parsed and validated,
  **then** no error or warning is emitted — the block is fully optional.

## Grammar

Addition to `UrkelFile`:

```ebnf
UrkelFile ::= { TriviaLine }
              MachineDecl
              { TriviaLine }
              { ImportDecl TriviaLine* }
              { ParallelDecl TriviaLine* }
              StatesBlock
              { TriviaLine }
              { EntryExitDecl TriviaLine* }
              TransitionsBlock
              { TriviaLine }
              [ InvariantsBlock ]   ← new
              { TriviaLine }
```

New productions:

```ebnf
InvariantsBlock ::= { Whitespace } "@invariants" { Whitespace } Newline
                    { TriviaLine | InvariantDecl }

InvariantDecl   ::= { Whitespace } InvariantExpr { Whitespace } Newline

InvariantExpr   ::= "reachable"       "(" InvariantPath ")"
                  | "unreachable"     "(" InvariantPath ")"
                  | "noDeadlock"
                  | "deterministic"
                  | "acyclic"
                  | "allPathsReachFinal"

InvariantPath   ::= InvariantRef
                  | InvariantRef { Whitespace } "->" { Whitespace } InvariantRef

InvariantRef    ::= StateRef                       /* local: Idle, Active.Playing */
                  | Identifier "::" ReactiveState  /* sub-machine / parallel region */
```

New contextual keywords (only reserved inside `@invariants` block):
`reachable`, `unreachable`, `noDeadlock`, `deterministic`, `acyclic`,
`allPathsReachFinal`.

`@invariants` is added to the global `Keywords` set.

## Notes

- **Violation reporting includes a witness.** When `reachable(A)` fails, the
  error message says "no path from init to A". When `unreachable(A -> B)` fails,
  the error includes the shortest violating path found by BFS:
  `"path found: A → event1 → C → event2 → B"`.

- **Multiple violations per block.** The validator collects ALL invariant
  violations in one pass and returns them all, never stopping on the first
  failure. A developer fixing three invariants should not have to re-run three
  times.

- **Interaction with `@parallel` regions.** `reachable(P::done)` checks that
  all regions of parallel block `P` can reach their final states simultaneously.
  `reachable(P.R::State)` checks the specific region `R`'s reachability.

- **Relationship to the validator's built-in checks.** Some invariants overlap
  with existing validator rules (e.g. the validator already warns on dead states,
  which is what `noDeadlock` formalises). Declaring `noDeadlock` elevates the
  existing warning to a hard error for that machine, making the contract explicit
  in the source file.

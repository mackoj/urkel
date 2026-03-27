# US-12.4: Parallel States (Orthogonal Regions)

## 1. Objective

Extend the `.urkel` DSL and compiler to support **parallel states** — states composed of two or more independent regions that are all active simultaneously — allowing Urkel to model concurrent aspects of a system without spawning separate machines.

## 2. Context

Some systems have genuinely independent concerns that must be tracked at the same time. A media player has both a playback state (`Playing`/`Paused`) and a volume state (`Normal`/`Muted`) that are orthogonal — you can be paused and muted, playing and unmuted, etc. XState calls these **parallel states** (type: `'parallel'`); Harel's original formalism calls them **orthogonal components**.

In Urkel v2, a parallel state is declared with the `@parallel` keyword followed by a block name and two or more `region` sub-blocks. Each region is an independent sub-machine with its own `init` and `state` declarations. Events are dispatched to all active regions simultaneously; a region ignores events it has no transition for.

Unlike `@compose`, which spawns a separate top-level machine, `@parallel` models **intra-machine** concurrency and the combined state is a product type of all active region states.

## 3. Acceptance Criteria

* **Given** a `@parallel BlockName` declaration with two `region` blocks, **when** the machine enters the parallel state, **then** both regions are simultaneously active and both initial states are entered.

* **Given** an event that is handled in one region but not another, **when** the machine receives that event, **then** only the handling region transitions; the other region remains in its current state.

* **Given** an event handled by both regions, **when** the machine receives it, **then** both regions transition simultaneously.

* **Given** all regions have reached their `final` child states, **when** the last region finalizes, **then** the parallel state itself is considered complete and any `onDone` transition fires.

* **Given** a `.urkel` file with a parallel state, **when** Swift is generated, **then** the combined state is represented as a struct or tuple of the individual region states, maintaining compile-time safety for each region independently.

* **Given** a `region` block missing an `init` child state, **when** the semantic validator runs, **then** it emits a clear error.

* **Given** the visualizer (US-13.1), **when** a parallel state is present, **then** it renders regions separated by dashed lines, consistent with standard statechart notation.

## 4. Implementation Details

* **DSL syntax:**
  ```
  @parallel ActiveSession
    region Playback
      init Playing
      state Paused
    region Quality
      init Auto
      state HD
      state SD
  ```

* **grammar.ebnf:**
  ```ebnf
  ParallelDecl   ::= "@parallel" Identifier Newline (Indent RegionDecl+ Dedent)
  RegionDecl     ::= "region" Identifier Newline (Indent StateDecl+ Dedent)
  ```

* **AST** — new `ParallelNode` containing `name: String` and `regions: [RegionNode]`. Each `RegionNode` has `name: String` and `states: [StateNode]`.

* **Parser** — `@parallel` is parsed as a top-level state-section construct. Regions use the same indentation-tracking logic as compound states (US-12.3).

* **Semantic validator** — each region must have exactly one `init` state; regions within the same parallel block must have unique state names to avoid ambiguity.

* **SwiftCodeEmitter** — the combined parallel state type is a product: `Machine<ParallelState<PlaybackState, QualityState>>`. Transition methods on the machine check and advance each region's state independently. This is the most complex emitter addition in DSL v2.

* **onDone transition** — special `@onDone ParallelName -> TargetState` syntax (can be deferred to a follow-up story if needed).

## 5. Testing Strategy

* Parser: single parallel state; parallel alongside flat states; nested compound inside region.
* Semantic validator: region with no `init` → error; duplicate state names across regions → error.
* Emitter: both regions entered on parallel state entry; independent region transitions; combined state type is correct product.
* Integration: compile generated Swift for a machine with a two-region parallel state.
* Fixture: `ParallelMachine` (e.g., media player with playback + volume regions) in `Tests/UrkelTests/Fixtures/`.

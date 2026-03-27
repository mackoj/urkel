# US-14.2: Delayed Transitions (`after(duration)`)

## 1. Objective

Extend the `.urkel` DSL to support **time-based transitions** — transitions that fire automatically after a specified duration if no other event has moved the machine out of the current state first.

## 2. Context

Nearly every real state machine has at least one timeout: a connection attempt that times out after 30 seconds, a session that expires after 30 minutes, a loading spinner that gives up after 10 seconds. Currently, Urkel developers implement these with manual `Task.sleep` calls inside transition closures, which works but is invisible to the DSL, the visualizer, the simulator, and the test stub generator.

XState models these as `after` transitions: a special event type that fires on a timer. The timer starts when the state is entered and is automatically cancelled if another event exits the state first.

In Urkel, `after(duration)` is syntactic sugar: the compiler generates a `Task.sleep`-based trigger inside the state's entry logic, with automatic cancellation on early exit — the same pattern a developer would write by hand, but declared explicitly in the DSL so all tooling can see it.

## 3. Acceptance Criteria

* **Given** a transition `Idle -> after(30s) -> TimedOut`, **when** the machine enters `Idle` and no other transition fires within 30 seconds, **then** the machine automatically transitions to `TimedOut`.

* **Given** a timed transition where another event fires before the timeout, **when** that event causes a transition out of the state, **then** the pending timer is cancelled and `TimedOut` never fires.

* **Given** multiple `after` transitions on the same state with different durations, **when** the machine enters the state, **then** the shortest applicable timer fires first (only one `after` transition fires per state entry).

* **Given** duration literals in the DSL, **when** parsed, **then** the following units are supported: `ms` (milliseconds), `s` (seconds), `min` (minutes); e.g., `after(500ms)`, `after(30s)`, `after(5min)`.

* **Given** a `.urkel` file with `after` transitions, **when** code is generated, **then** a `Task` is spawned on state entry with `try await Task.sleep(for: .seconds(30))`; if the sleep completes, the timed transition fires; the task handle is stored for cancellation.

* **Given** the Visualizer (US-13.1), **when** a state has a timed transition, **then** the transition arrow is rendered with a clock icon and the duration label.

* **Given** the Simulate mode (US-13.2), **when** a state with a timed transition is active, **then** a timer indicator shows in the sidebar with a `Fast-forward` button to immediately trigger the timeout without waiting.

* **Given** generated test stubs (US-13.4), **when** a path includes a timed transition, **then** the stub includes a comment `// after(30s) — use clock dependency to control time in tests`.

## 4. Implementation Details

* **DSL syntax** (timed transition is a special event name):
  ```
  @transitions
    Idle        -> after(30s)   -> TimedOut
    Connecting  -> after(10s)   -> ConnectionFailed
    Playing     -> after(5min)  -> AutoPaused    / savePosition
  ```

* **grammar.ebnf — add `AfterEvent`:**
  ```ebnf
  EventDecl   ::= Identifier ("(" ParamList ")")? | AfterEvent
  AfterEvent  ::= "after" "(" Duration ")"
  Duration    ::= Number DurationUnit
  DurationUnit ::= "ms" | "s" | "min"
  ```

* **AST** — `TransitionNode` gains `isDelayed: Bool`, `delayDuration: TimeInterval?`. The event name for delayed transitions is stored as `"after(\(duration)s)"` internally for uniqueness.

* **Parser** — detect `after(` in the event position; parse the numeric literal and unit; convert to `TimeInterval`.

* **Semantic validator** — warn if a state has more than one `after` transition (ambiguous which fires first); error if duration is zero or negative; error if `after` transition has parameters (timers carry no payload).

* **SwiftCodeEmitter** — on state entry, alongside any `@invoke` task (US-14.1), spawn a timer `Task`:
  ```swift
  let timerTask = Task {
      try await Task.sleep(for: .seconds(30))
      // fire transition
  }
  // store timerTask handle; cancel on any other transition
  ```
  Use `withTaskCancellationHandler` for clean cancellation semantics.

* **Clock dependency** — to make timers testable, inject the clock as a `ClockDependency` via `swift-dependencies`, consistent with Point-Free's `withDependencies` pattern. Generated `Client` gains `var clock: any Clock<Duration>` when any timed transition is present.

## 5. Testing Strategy

* Parser: `after(30s)`, `after(500ms)`, `after(5min)`; zero duration → error; negative → error; `after` with params → error.
* Semantic validator: two `after` transitions on same state → warning.
* Emitter: timer task spawned on entry; cancelled on early exit; fires correctly after duration using controlled clock.
* Test with `ImmediateClock` from `swift-clocks` to verify timer fires synchronously in tests without real waiting.
* Integration: compile machine with delayed transitions. Verify no timer leak (task is always cancelled or completed).
* Fixture: `TimeoutMachine` (connection attempt with 10s timeout) in `Tests/UrkelTests/Fixtures/`.

# US-12.8: Final State Output Data

## 1. Objective

Extend the `.urkel` DSL to allow `final` states to carry **typed output data** — a value produced when the machine terminates — making the machine's result an explicit, type-safe part of its contract rather than something the caller must infer from side effects.

## 2. Context

In XState, final states can emit `output` data that becomes available on the actor when it stops. This models the FSM as a typed function: given inputs (the factory parameters), it eventually produces a typed output (the final state's value). This is especially important for machines that represent async operations with a clear result — a login flow produces a `User`, a payment flow produces a `Receipt`, a file upload produces a `URL`.

Without final state output, Urkel callers must reconstruct the result from side effects stored in the context, which couples the caller tightly to implementation details. With typed final output, the contract is: `Machine<Success>` has a `.user: User` property — the result is self-contained in the machine value.

In Urkel's typestate model, this is natural: `Machine<Success>` is a Swift struct that can carry stored properties. The generated `Success` typestate marker becomes a struct (not an empty enum) when it carries data. The caller pattern-matches on the final machine value and reads the output directly.

## 3. Acceptance Criteria

* **Given** `final Success(user: User)` in `@states`, **when** Swift is generated, **then** `Success` is emitted as a `struct` with a `let user: User` property rather than an empty `enum`.

* **Given** a transition `Verifying -> verified(user: User) -> Success`, **when** code is generated, **then** the `verified` transition method constructs `Machine<Success>` with `Success(user: user)` — the event parameter becomes the output.

* **Given** multiple `final` states with different output types, **when** the caller holds a machine value, **then** they can switch over the state enum and access the typed output of each final state independently.

* **Given** a `final` state with no output parameters (e.g., `final Cancelled`), **when** Swift is generated, **then** it is emitted as an empty `enum` as before — no change to existing behavior.

* **Given** a transition targeting a `final Success(user: User)` state but not supplying the required `user` parameter, **when** the semantic validator runs, **then** it emits an error: `"Transition to 'Success' must provide parameter 'user: User'"`.

* **Given** the Visualizer (US-13.1), **when** a final state carries output data, **then** it renders with a small type annotation showing the output type (e.g., `Success → User`).

* **Given** generated test stubs (US-13.4), **when** a path ends in a final state with output, **then** the stub includes `#expect(finalMachine.user == expectedUser)` as a placeholder assertion.

## 4. Implementation Details

* **DSL syntax:**
  ```
  @states
    final Success(user: User)         # typed output — one or more named params
    final Failure(error: Error)
    final Cancelled                   # no output — unchanged behavior

  @transitions
    Verifying -> verified(user: User)     -> Success
    Verifying -> verifyFailed(error: Error) -> Failure
    *         -> cancel                    -> Cancelled
  ```

* **grammar.ebnf — extend `StateDecl`:**
  ```ebnf
  StateDecl    ::= StateKind Identifier OutputParams? HistoryModifier? Newline ...
  OutputParams ::= "(" ParamList ")"
  ```
  `OutputParams` is only valid when `StateKind` is `final`. The validator enforces this.

* **AST** — `StateNode` gains `outputParams: [(name: String, type: String)]`. Non-empty only for `final` states.

* **Parameter matching** — the semantic validator verifies that every transition targeting a `final` state with output provides exactly the matching parameters (names and types) as event parameters. The event's parameters become the output's values.

* **SwiftCodeEmitter** — when `outputParams` is non-empty on a `final` state, emit it as a `struct` instead of an empty `enum`:
  ```swift
  // Without output (existing):
  public enum Cancelled {}

  // With output (new):
  public struct Success: ~Copyable, Sendable {
      public let user: User
  }
  ```
  The transition method constructs the output:
  ```swift
  public consuming func verified(user: User) -> Machine<Success> {
      Machine<Success>(internalState: Success(user: user), /* ... */)
  }
  ```

* **Caller pattern** — the combined state enum makes the output accessible:
  ```swift
  switch consume machine {
  case .success(let m):
      print("Logged in as \(m.internalState.user.name)")
  case .failure(let m):
      throw m.internalState.error
  case .cancelled:
      break
  }
  ```

* **Template model** — add `outputParams` array to the Mustache state model so custom templates (Kotlin, etc.) can also render typed final outputs.

## 5. Testing Strategy

* Parser: `final Success(user: User)` parses correctly; multiple output params; output params on `state` (non-final) → error.
* Semantic validator: transition to output-carrying final with wrong/missing params → error; transition with matching params → passes.
* Emitter: `final` with params → `struct` in output; `final` without params → `enum` (no regression); `Machine<Success>` carries `Success(user:)` after transition.
* Caller API: `switch consume machine` correctly exposes typed output; accessing `.user` is a compile-time checked property, not a runtime cast.
* Integration: compile a machine with mixed final states (some with output, some without). Add to `generatedSwiftCompiles`.
* Kotlin template: `final Success(user: User)` generates a Kotlin `data class Success(val user: User)`.
* Fixture: `LoginMachine` (`final Success(user: User)`, `final Cancelled`, `final Failed(error: Error)`) in `Tests/UrkelTests/Fixtures/`.

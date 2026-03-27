# US-14.1: `@invoke` — Async Operations as First-Class State Semantics

## 1. Objective

Extend the `.urkel` DSL to support `@invoke` declarations on states, modelling asynchronous work (a network call, a file operation, a child machine) as a first-class state concept with automatic `onDone` and `onError` transition outcomes.

## 2. Context

The most common pattern in real-world state machines is a **loading/waiting state**: the machine enters a state because it is waiting for an asynchronous operation to complete. Currently in Urkel, this async work lives invisibly inside the closure injected for the transition that entered the state. The DSL has no knowledge that `Loading` exists because the machine is waiting for a network call — it just sees a state with no semantic annotation.

XState solves this with `invoke`: when a state is entered, it automatically starts an invoked service (a promise, callback, or child machine). When the service resolves, an `onDone` transition fires automatically; if it rejects, an `onError` transition fires. This makes the intent of a loading state **explicit and readable** in the DSL.

In Urkel, `@invoke` follows the same philosophy as guards and actions: the **name** of the invoked service is declared in the DSL; the **implementation** is a Swift async closure injected via the `Client` struct. The emitter generates the call site and the `onDone`/`onError` branching automatically.

## 3. Acceptance Criteria

* **Given** a state with an `@invoke` declaration, **when** the machine enters that state, **then** the generated Swift code automatically starts the invoked async operation (by calling the corresponding closure on the `Client`).

* **Given** an `@invoke` with an `onDone` transition target, **when** the invoked operation completes successfully, **then** the machine automatically transitions to the `onDone` target state without any explicit event from the caller.

* **Given** an `@invoke` with an `onError` transition target, **when** the invoked operation throws an error, **then** the machine automatically transitions to the `onError` target state, carrying the error as an event parameter.

* **Given** an `@invoke` with a result type, **when** `onDone` fires, **then** the result value is available as a typed parameter on the generated transition (e.g., `onDone(user: User) -> Success`).

* **Given** a state with `@invoke` that is exited before the invocation completes (e.g., a cancellation event fires first), **when** the state is exited, **then** the in-flight operation is cancelled (Swift structured concurrency `Task` cancellation).

* **Given** a `.urkel` file with `@invoke` declarations, **when** code is generated, **then** each unique invocation name appears as a `var invocationName: @Sendable (ParamTypes) async throws -> ResultType` closure on the `Client` struct.

* **Given** the Visualizer (US-13.1), **when** a state has `@invoke`, **then** it renders with a distinct visual indicator (e.g., an async symbol or dashed border) and the `onDone`/`onError` transitions are rendered in a different colour from regular transitions.

## 4. Implementation Details

* **DSL syntax:**
  ```
  state Loading
    @invoke fetchUser(id: UserID) -> User
      onDone(user: User)  -> Success
      onError(error: Error) -> Failure

  state Connecting
    @invoke openSocket(url: URL)
      onDone              -> Connected
      onError(error: Error) -> Error
  ```

* **grammar.ebnf — add `InvokeDecl`:**
  ```ebnf
  InvokeDecl   ::= "@invoke" Identifier "(" ParamList? ")" ("->" TypeIdentifier)?
                   Newline InvokeDoneClause InvokeErrorClause?
  InvokeDoneClause  ::= Indent "onDone" ("(" ParamList ")")? "->" Identifier Dedent
  InvokeErrorClause ::= Indent "onError" ("(" ParamList ")")? "->" Identifier Dedent
  ```

* **AST** — `StateNode` gains `invoke: InvokeNode?`. `InvokeNode` contains `serviceName`, `inputParams`, `resultType`, `onDoneTarget`, `onDoneParams`, `onErrorTarget`, `onErrorParams`.

* **Parser** — `@invoke` is parsed as a child declaration inside a `state` block (works alongside compound child states from US-12.3).

* **Semantic validator** — `onDone` and `onError` target states must exist; invoked service name must not clash with transition event names; a state cannot have both `@invoke` and be `final`.

* **SwiftCodeEmitter** — the state's generated entry point spawns a `Task` that calls the service closure. The task stores a `Task` handle in the machine value for cancellation. On completion, the task calls the `onDone` or `onError` transition method on the machine continuation. Uses Swift structured concurrency throughout.

* **Client struct** — each invoked service becomes a typed async closure property:
  ```swift
  var fetchUser: @Sendable (_ id: UserID) async throws -> User
  ```

## 5. Testing Strategy

* Parser: `@invoke` with result type; `@invoke` with no params; `@invoke` inside compound state; missing `onDone` → parser error.
* Semantic validator: `onDone` target doesn't exist → error; duplicate `@invoke` on same state → error.
* Emitter: task is spawned on entry; task is cancelled on early exit; `onDone` fires with correct result; `onError` fires on throw.
* Concurrency: verify no data races under Swift 6 strict concurrency (`-strict-concurrency=complete`).
* Integration: compile generated code for a machine with `@invoke`. Add to `generatedSwiftCompiles` suite.
* Fixture: `InvokeMachine` (e.g., a user-fetching flow: `Idle → Loading[@invoke fetchUser] → Success / Failure`) in `Tests/UrkelTests/Fixtures/`.

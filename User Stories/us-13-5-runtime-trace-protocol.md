# US-13.5: Runtime Trace Protocol (Inspector Foundation)

## 1. Objective

Extend the Swift code generator to optionally emit a **runtime trace channel** — an `AsyncStream<UrkelEvent>` on the `Client` struct — that broadcasts a structured event on every state transition, enabling runtime inspection, debugging, and the foundation for a future live Inspector tool.

## 2. Context

Urkel's typestate design encodes state in the Swift type system, making it invisible at runtime — there is no `currentState` property to observe. This is intentional and correct for production code. However, during development, debugging, and testing, developers need to observe what transitions are firing, in what order, and with what parameters.

XState solves this with `@statelyai/inspect` — an actor subscribes to all state changes and events, which are forwarded to the Stately Inspector UI. Urkel's equivalent must work without a runtime interpreter, by generating observation hooks into the transition methods themselves.

The trace channel is **opt-in**: enabled by a `tracing: true` flag in `urkel-config.json` or `#if DEBUG` conditional compilation. In production builds it compiles to a no-op. The generated `UrkelEvent` type is defined in a shared `UrkelRuntime` micro-library (or inlined into each generated file).

## 3. Acceptance Criteria

* **Given** `tracing: true` in `urkel-config.json`, **when** Swift is generated, **then** the `Client` struct gains a `var events: AsyncStream<UrkelEvent> { get }` property.

* **Given** any transition method is called on the machine, **when** the transition completes, **then** a `UrkelEvent` is emitted on the stream containing: `machineName`, `from` (state name as `String`), `to` (state name as `String`), `event` (event name as `String`), `parameters` (key-value pairs as `[String: String]`), and `timestamp`.

* **Given** a machine with entry/exit actions (US-12.2), **when** they fire, **then** corresponding `UrkelEvent` entries of kind `.entryAction` and `.exitAction` are emitted before/after the transition event.

* **Given** `tracing: false` (the default), **when** Swift is generated, **then** no trace code is emitted and the `Client` struct has no `events` property — zero overhead in production.

* **Given** the trace stream, **when** a developer subscribes in a debug build, **then** they can log, display, or forward events without modifying any machine logic.

* **Given** the trace stream and a future Inspector companion app, **when** the app connects via a local WebSocket or Multipeer channel, **then** it can receive `UrkelEvent` values and display a live state machine diagram with current state highlighted.

* **Given** the `UrkelEvent` type, **when** it is defined, **then** it conforms to `Sendable`, `Codable`, and `CustomStringConvertible` so it can be logged, serialized, or forwarded over a network.

## 4. Implementation Details

* **`UrkelEvent` type** (emitted inline or from a future `UrkelRuntime` library):
  ```swift
  public struct UrkelEvent: Sendable, Codable, CustomStringConvertible {
      public enum Kind: String, Sendable, Codable {
          case transition, entryAction, exitAction, internalTransition
      }
      public let id: UUID
      public let machine: String
      public let kind: Kind
      public let from: String
      public let to: String?        // nil for entry/exit actions
      public let event: String
      public let parameters: [String: String]
      public let timestamp: Date

      public var description: String {
          "[\(machine)] \(from) → \(event) → \(to ?? "—")"
      }
  }
  ```

* **Trace continuation** — the `Client` holds an `AsyncStream<UrkelEvent>.Continuation` internally. `var events: AsyncStream<UrkelEvent>` is generated as a computed property backed by the continuation.

* **Injection into transition methods** — the emitter wraps the body of each generated transition method:
  ```swift
  // Before (existing):
  public consuming func load(url: URL) async -> Machine<Loading> { ... }

  // After (with tracing):
  public consuming func load(url: URL) async -> Machine<Loading> {
      _traceContinuation?.yield(UrkelEvent(machine: "VideoPlayer", kind: .transition,
          from: "Idle", to: "Loading", event: "load",
          parameters: ["url": "\(url)"], timestamp: .now))
      // ... existing transition body
  }
  ```

* **Conditional compilation** — wrap all trace code in `#if DEBUG` when `tracing: "debug-only"` is set (vs. `tracing: true` which always emits).

* **Config key:**
  ```json
  { "tracing": "debug-only" }   // #if DEBUG
  { "tracing": true }            // always
  { "tracing": false }           // never (default)
  ```

* **`UrkelResolvedConfiguration`** — add `tracing: TracingMode` enum (`.never`, `.debugOnly`, `.always`).

## 5. Testing Strategy

* Unit-test emitter: `tracing: false` → no `events` property in output; `tracing: true` → `events` present and `UrkelEvent` yield call in each transition.
* Integration: subscribe to `events` stream in a test; fire three transitions; verify three events received in order with correct `from`/`to`/`event` values.
* `UrkelEvent` Codable round-trip test.
* Verify zero-overhead: in a `tracing: false` build, `Client` struct size is unchanged from baseline.
* Fixture: `TracedMachine` in `Tests/UrkelTests/Fixtures/` exercising all event kinds (transition, entry, exit, internal).

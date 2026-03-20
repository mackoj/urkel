# US-9.4: Runtime Stream Helpers

## 1. Objective
Create reusable runtime helpers for event-driven FSMs so packages do not keep rewriting async stream setup, continuation management, cancellation, and finish logic.

## 2. Context
FolderWatch uses an async throwing stream to surface file events. That pattern is useful whenever a machine needs to emit a sequence of events, not just for file watching.

## 3. Acceptance Criteria
* **Given** an event-driven machine runtime.
* **When** Urkel emits helper code.
* **Then** the runtime can create, yield to, and finish an async event stream safely.

* **Given** the runtime is stopped or failed.
* **When** cleanup happens.
* **Then** pending work is cancelled and the stream is completed exactly once.

* **Given** the package wants debouncing or batching.
* **When** it configures the helper.
* **Then** the helper supports that policy without requiring custom one-off stream plumbing.

## 4. Implementation Details
* Factor the common stream lifecycle into a generic helper or template.
* Keep the event type generic so the same code works for any FSM that emits asynchronous events.
* Preserve explicit error propagation instead of swallowing failures in callbacks or tasks.

## 5. Testing Strategy
* Add unit tests for event ordering, cancellation, and finish behavior.
* Add a debounced event test to ensure the helper remains deterministic.

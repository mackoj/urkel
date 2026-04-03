# US-5.17: CounterState Async Forwarding & In-Place Method Delegation

## Objective

Extend the generated combined-state enum (`XxxState`) with:

1. **`async` variants of `withX` accessors** — so callers can `await`
   async machine methods through the dynamic wrapper without leaving the
   pattern-match style.
2. **Direct in-place method forwarding** — `borrowing func increment()`
   and similar on `XxxState` so callers don't need a `withActive` closure
   just to call a zero-argument in-place handler.
3. **`outputs` property forwarding** on `XxxState` — so the output stream
   is accessible without unwrapping.

## Background

The generated `XxxState` enum is the *dynamic dispatch* entry point for
callers who don't know the machine's current phase at compile time. Today
it only forwards *consuming* transitions (`start()`, `reset()`, `finish()`).

Three gaps prevent ergonomic use:

### Gap 1 — `withX` is synchronous

```swift
// Current generated accessor:
public borrowing func withActive<R>(
    _ body: (borrowing CounterMachine<CounterPhase.Active>) throws -> R
) rethrows -> R?

// Problem: body cannot contain await
state.withActive { m in await m.increment() }   // ❌ async in non-async closure
```

### Gap 2 — No forwarding for `borrowing func` in-place methods

```swift
// Desired:
await state.increment()   // ✅ direct call, no closure needed

// Current: must write:
await state.withActiveAsync { m in await m.increment() }   // verbose
```

### Gap 3 — `outputs` not accessible from `XxxState`

```swift
// Desired:
for await event in state.outputs { … }

// Current: no `outputs` property on CounterState — must withActive first
```

## Input DSL (counter from US-5.15)

```
machine Counter
…
@transitions
  Active -*> increment  / incrementCount
  Active -*> decrement  / decrementCount
  Active -*> value(count: Int)
  …
```

## Generated Output (delta on `XxxState`)

### 1. `async` variants of `withX`

Generated alongside the existing sync variants:

```swift
extension CounterState {

    // Existing sync accessor (unchanged):
    public borrowing func withActive<R>(
        _ body: (borrowing CounterMachine<CounterPhase.Active>) throws -> R
    ) rethrows -> R? {
        switch self {
        case .active(let m): return try body(m)
        default: return nil
        }
    }

    // NEW — async variant:
    public borrowing func withActiveAsync<R>(
        _ body: (borrowing CounterMachine<CounterPhase.Active>) async throws -> R
    ) async rethrows -> R? {
        switch self {
        case .active(let m): return try await body(m)
        default: return nil
        }
    }
}
```

Generated for **every** state. The `async rethrows` pattern is correct
Swift — a function may be `async` and `rethrows` simultaneously.

### 2. Direct in-place method forwarding

For every `borrowing func` declared on a phase extension (in-place
handlers from `-*> event / action`), generate a same-named `borrowing`
method on `XxxState` that no-ops silently in non-matching states:

```swift
extension CounterState {

    /// Sends `increment` to the machine. No-op if not in `Active`.
    public borrowing func increment() async {
        switch self {
        case .active(let m): await m.increment()
        default: break
        }
    }

    /// Sends `decrement` to the machine. No-op if not in `Active`.
    public borrowing func decrement() async {
        switch self {
        case .active(let m): await m.decrement()
        default: break
        }
    }
}
```

The no-op-in-wrong-phase behaviour is intentional and documented in the
method comment — it mirrors the existing consuming-transition forwarding
(`start()` no-ops in `Active` and `Done`).

### 3. `outputs` forwarding on `XxxState`

```swift
extension CounterState {

    /// Output event stream. `nil` when not in `Active`.
    public borrowing var outputs: AsyncStream<CounterOutput>? {
        switch self {
        case .active(let m): return m.outputs
        default: return nil
        }
    }
}
```

Returns `Optional` because the stream is only meaningful in the phase
that declares the output event. If output events exist on multiple phases,
a separate property is generated for each.

## Usage after this story

```swift
// Dynamic dispatch — no phase known at compile time
var state: CounterState = CounterState(counter.makeObserver())

// Subscribe to outputs before starting
Task {
    while let stream = state.outputs {   // nil until Active
        for await event in stream {
            // handle event
        }
    }
}

state = await state.start()           // consuming forward
await state.increment()               // ✅ direct call — no closure
await state.decrement()               // ✅
state = state.finish()                // consuming forward
```

## Acceptance Criteria

* **Given** `Active -*> increment / incrementCount`, **when** `XxxState`
  is emitted, **then** a `public borrowing func increment() async` is
  generated on `XxxState` that delegates to the `.active` case and
  no-ops in all other cases.

* **Given** any state `Foo`, **when** emitted, **then** both
  `withFoo<R>(_ body: (borrowing …) throws -> R) rethrows -> R?` and
  `withFooAsync<R>(_ body: (borrowing …) async throws -> R) async rethrows -> R?`
  are generated.

* **Given** `Active -*> value(count: Int)` (output event), **when**
  `XxxState` is emitted, **then** `public borrowing var outputs: AsyncStream<CounterOutput>?`
  is generated, returning the stream in `.active` and `nil` otherwise.

* **Given** the combined state is in `.idle`, **when** `state.increment()`
  is called, **then** no crash occurs (no-op).

* **Given** the combined state is in `.active`, **when**
  `await state.withActiveAsync { m in await m.increment() }` is called,
  **then** the action runs and the result is non-nil.

* **Given** all emitted files, **when** parsed by SwiftParser, **then**
  no syntax errors.

## Testing Strategy

* Snapshot test: `CounterMachine.swift` includes `withActiveAsync`, direct
  `increment()` / `decrement()`, and `outputs` property on `CounterState`.
* Unit test: create noop machine, advance to `CounterState`, call
  `state.increment()` — no crash, machine still in `.active`.
* Unit test: `withActiveAsync` — assert non-nil result in active state,
  nil in idle state.
* Unit test: `state.outputs` is non-nil in `.active`, nil in `.idle`.

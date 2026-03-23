# Design Intelligence and Trade-Offs

Understand why Urkel's architecture is exceptional, and where it requires careful consideration.

## Overview

Urkel is built on the insight that three safety properties—type safety, memory safety, and concurrency safety—can be combined into a single architecture. Most FSM libraries solve one or two of these problems. Urkel solves all three simultaneously.

This article explores:
- Why the typestate + noncopyable combination is genius
- What trade-offs this introduces
- When Urkel is the right choice vs. when simpler approaches suffice
- How Urkel compares to other patterns used in production Swift code

## The Three Pillars of Urkel Safety

### Pillar 1: Type-Level Safety

Illegal transitions are **unrepresentable**—not just disallowed, but literally impossible to write in code.

**Traditional approach (enum-based):**
```swift
enum State { case idle, running, stopped }

struct Car {
    var state: State = .idle
    
    func accelerate() {
        guard state == .running else { 
            print("Can't accelerate while stopped")
            return 
        }
        // do work
    }
}

// ❌ Wrong code compiles; only fails at runtime
car.state = .idle
car.accelerate()  // prints warning; returns silently
```

**Urkel approach:**
```swift
extension Car where State == Running {
    public consuming func accelerate() -> Car<Running> {
        // do work
        return updated
    }
}

// ❌ This code doesn't even compile
let idle = Car<Idle>()
await idle.accelerate()  
// error: value of type 'Car<Idle>' has no member 'accelerate'
```

Type safety in Urkel is **compile-time checked**. The compiler is your first line of defense.

### Pillar 2: Memory Safety (Noncopyable Types)

State cannot be duplicated—only moved. This prevents entire classes of race conditions.

**The problem:**
```swift
var state = State.idle
let copy = state  // ❌ Now you have two copies of the same state

// In Task A:
state = .running

// In Task B:
print(copy)  // Still .idle? Or .running?
             // You just created a race condition
```

**Urkel's solution:**
```swift
var machine = Machine<Idle>()
let copy = machine  // ❌ COMPILE ERROR
// error: cannot copy noncopyable type 'Machine<Idle>'

// Instead, you *move* the state:
let running = await machine.start()  // machine is consumed
// machine no longer exists; no duplicate references possible
```

Because machines are `~Copyable`, you **cannot create a duplicate**. There is only ever one reference to the current state. This is a **memory safety guarantee**—the compiler enforces single ownership.

### Pillar 3: Concurrency Safety (@Sendable Closures)

All transitions are `@Sendable` closures, so they're compatible with Swift 6 strict concurrency checking without additional annotations.

**Without @Sendable:**
```swift
var mutableState = State.idle

let transition: () async -> State = {
    mutableState = .running  // ⚠️ Captures mutable state
    return .running
}

// Send across actor boundary?
await someActor.performTransition(transition)
// ❌ ERROR: Sending 'transition' risks causing data races
```

**With @Sendable (Urkel's way):**
```swift
let transition: @Sendable () async -> Machine<Running> = {
    // Can only capture Sendable types
    // No mutable state capture
    return Machine<Running>(...)
}

// Send across actor boundary?
await someActor.performTransition(transition)
// ✅ OK: Compiler verified safety
```

Urkel generates all transitions as `@Sendable` automatically. You get concurrency safety with zero additional boilerplate.

---

## Why This Combination Is Powerful

Each pillar alone is valuable. Together, they create a **mathematically certain** state machine:

| Scenario | Enum FSM | Manual Actor | **Urkel** |
|----------|----------|--------------|-----------|
| Wrong method call | Runtime guard | N/A (compile-time types) | Compile error |
| State duplicated in Task A and B | Possible race condition | Prevented by actor lock | Impossible (not copyable) |
| Closure captures mutable state | Unsafe | Possible (need discipline) | Compile error (@Sendable) |
| Multiple concurrent transitions | Possible (needs locking) | Prevented by actor | Impossible (state consumed) |
| Forget to handle final state | Runtime check | N/A (your responsibility) | Compiler warning (unused) |

Urkel makes almost *every* kind of state machine bug impossible.

---

## Real-World Benefit: Complex Async Workflows

Consider a file watcher that must:
1. Start watching a directory (Idle → Running)
2. Handle errors without dropping to a safe state (Running → Running)
3. Stop watching (Running → Stopped)
4. Never allow calling start() twice in a row
5. Never race with concurrent stop() and error() calls

**With enum FSM and manual locking:**
```swift
actor FileWatcher {
    private var state: State = .idle
    
    func start() async throws {
        // Need locks to prevent races
        // Need to guard the wrong state
        guard state == .idle else { throw WatcherError.alreadyRunning }
        state = .running
        // What if another task changes state here?
    }
    
    func error(_ err: Error) async {
        guard state == .running else { return }
        // Error is lost if state changed
        state = .running
    }
    
    func stop() async {
        guard state == .running else { return }
        state = .stopped
    }
}
```

This code has **subtle race conditions**. The `guard` statement checks state, but another task can change it before the assignment.

**With Urkel:**
```swift
public consuming func start() async -> FileWatcher<Running> {
    // Impossible to call if not in Idle state
    // start() consumed the Idle machine; 
    // you cannot call start() again
    return FileWatcher<Running>(...)
}

public consuming func error(err: Error) async -> FileWatcher<Running> {
    // Stay in Running; don't drop state
    return FileWatcher<Running>(...)
}

public consuming func stop() async -> FileWatcher<Stopped> {
    // Transition to final state; machine is consumed
    return FileWatcher<Stopped>(...)
}
```

This code is **provably correct**:
- You cannot call the wrong method (type system prevents it)
- You cannot have races (state is not shared)
- You cannot forget to transition (compiler warns if you don't)
- The type `FileWatcher<Running>` literally means "this machine is in the Running state"

---

## Trade-Offs: What Urkel Requires

Urkel's power comes with costs:

### 1. Requires Swift 5.9+

The noncopyable types feature (`~Copyable`) was introduced in Swift 5.9. If your project needs to support earlier versions, Urkel is not an option.

**Mitigation:** Swift 5.9 was released in September 2023. Most modern projects have migrated.

### 2. Verbose Generated Code

The generated state machine code is more verbose than a simple enum. Each state has its own initializer, each transition has documentation comments, and generic specialization adds size.

**Trade-off:** Verbosity is the price of type safety. The generated code is still readable and understandable.

### 3. Noncopyable Types Are Unfamiliar

Developers new to Swift 5.9+ features may find `~Copyable`, `consuming func`, and `borrowing` syntax confusing.

**Mitigation:** Urkel documentation includes clear examples. The Point-Free blog has excellent guides on these features.

### 4. Two Generation Modes Are Different

Closure-captured and context-threaded modes have different semantics. You must choose one per machine.

**Mitigation:** Start with closure-captured (the default). Only switch to context-threaded if you need shared state.

### 5. Limited Composition (Currently)

The `@compose` feature exists, but full sub-FSM orchestration isn't complete (Epic 11).

**Mitigation:** Use factory closures to pass pre-initialized sub-machines. Full orchestration is coming.

---

## Comparison to Alternatives

### Urkel vs Enum-Based FSMs

**Enum FSMs:**
```swift
enum State { case idle, running, stopped }
struct Machine {
    var state: State
    func transitionIfPossible() {
        guard state == .idle else { return }
        state = .running
    }
}
```

**Pros:**
- Familiar to all Swift developers
- Zero overhead
- Easy to understand

**Cons:**
- No compile-time validation of transitions
- State can be modified from anywhere
- No concurrency guarantees
- Race conditions possible

**Verdict:** Use enum if your state machine is trivial (2-3 states, no concurrency). Otherwise, Urkel is better.

### Urkel vs Redux/MVVM

Redux and similar patterns manage app-wide state with reducers.

**Pros:**
- Handles multiple independent pieces of state
- Time-travel debugging support
- Good for UI state

**Cons:**
- Global state object
- No compile-time guarantee of valid transitions
- Can be overkill for a simple state machine
- Reducers must be pure functions

**Verdict:** Use Redux for app state; Urkel for domain-specific state machines.

### Urkel vs Manual Actor Isolation

You can wrap state in an actor and handle transitions manually.

```swift
actor FileWatcher {
    var state: State = .idle
    
    func start() async throws {
        guard state == .idle else { throw Error.wrongState }
        state = .running
    }
}
```

**Pros:**
- Familiar (actors are built-in)
- Works for any level of Swift
- Good for mutable shared state

**Cons:**
- Still no compile-time validation
- Requires developer discipline to use correctly
- Actor overhead for simple machines
- Doesn't prevent bugs; just makes them less likely

**Verdict:** Use actors when you need mutable shared state. Use Urkel when you need immutable state machine semantics.

---

## When Urkel Is Overkill

You probably **don't** need Urkel if:

- Your state machine has 2-3 states and is never concurrent
- You're building UI state with MVVM or similar
- You need mutable shared state that's not a state machine
- Your team is not familiar with Swift 5.9+ features
- Your codebase doesn't have concurrency as a concern

In these cases, a simple enum FSM or actors will be simpler and more maintainable.

---

## When Urkel Shines

Urkel is the **right choice** when:

- You have a complex state machine (4+ states) with strict progression rules
- Concurrency safety is critical (async/await, multiple tasks)
- You want compile-time guarantees, not runtime guards
- Your team can commit to Swift 5.9+ features
- You value readability and type safety over simplicity

Examples:
- File watchers and file system operations
- Network state machines (connecting, connected, disconnected)
- Bluetooth state management (scanning, connected, bonding)
- Workflow engines with strict progression
- Game state machines with complex concurrent animations

---

## The Bottom Line

Urkel represents a **new level of correctness** for Swift state machines. By combining typestate, noncopyable types, and @Sendable closures, Urkel makes invalid states impossible rather than just unlikely.

The trade-off is learning new syntax and supporting Swift 5.9+. For projects where correctness and concurrency safety matter—which is most production code—this trade-off is worthwhile.

Choose Urkel when you want the compiler to catch your state machine bugs instead of hoping your runtime guards do.

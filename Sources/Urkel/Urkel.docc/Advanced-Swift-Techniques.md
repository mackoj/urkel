# Advanced Swift Techniques in Urkel

Explore the cutting-edge Swift features that power Urkel, and understand which proposals shape the design.

## Overview

Urkel was built to leverage and showcase the most advanced Swift features available. This article explains:

- Which Swift Evolution proposals inspire Urkel's architecture
- Which features are actively used in generated code
- Which proposals Urkel is prepared for (but not yet adopting)
- How to understand the advanced syntax in generated code
- Links to official proposals and deeper learning resources

## Actively Used Features

### SE-0426: Noncopyable Types (~Copyable)

**What it is:** A type can be marked `~Copyable` to forbid implicit copying.

**Where Urkel uses it:**
```swift
public struct Machine<State>: ~Copyable {
    // ...
}
```

Every generated FSM machine is noncopyable. This prevents accidental state duplication.

**Example:**
```swift
var idle = Machine<Idle>(...)
let copy = idle  // ❌ COMPILE ERROR
// error: cannot copy noncopyable type 'Machine<Idle>'

// Must move instead:
let running = await idle.start()  // idle is consumed
```

**Why it matters:** Eliminates race conditions from shared state references. You cannot accidentally have two independent copies of the same state.

**Reference:** [SE-0426 Proposed](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0426-noncopyable-types.md)

---

### SE-0431: `borrowing` and `consuming` Parameter Ownership Modifiers

**What it is:** Functions can explicitly mark parameters as `borrowing` (read-only use) or `consuming` (moves ownership).

**Where Urkel uses it:**

Every transition function uses `consuming`:

```swift
extension Machine where State == Idle {
    public consuming func start() async -> Machine<Running> {
        // `self` is consumed; old state is destroyed
        // You must return a new Machine<Running>
    }
}
```

**Example:**
```swift
var idle = Machine<Idle>(...)
let running = await idle.start()
// ❌ Try to use idle again:
await idle.stop()
// error: use of consumed value 'idle'
```

**Why it matters:** Forces linear progression through states. Once you call a transition, the old state is gone. No accidental reuse.

**Reference:** [SE-0431 Proposed](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0431-borrowing-and-consuming.md)

---

### SE-0286: Forward-Scanning Lookahead (Implicit Asynchrony)

**What it is:** Allows implicit async/await without explicit marking in some contexts.

**Where Urkel uses it:**
Transition functions are naturally async:

```swift
public consuming func start() async -> Machine<Running> {
    // Always async
    // Can call other async functions without ceremony
}
```

**Why it matters:** State machines often involve I/O. Implicit async support means your transitions feel natural.

**Reference:** [SE-0286 Adopted](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0286-implicit-init-convenience.md)

---

### SE-0289: Relational Operators as Protocol Witnesses

**What it is:** Simplifies generic type comparisons.

**Where Urkel uses it:**
Generic specialization on State markers:

```swift
extension Machine where State == Idle {
    // This method only exists when State == Idle
}

extension Machine where State == Running {
    // This method only exists when State == Running
}
```

**Why it matters:** The `where` clause enforces state-based specialization. You get different methods for different states.

**Reference:** [SE-0289 Adopted](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0289-relational-operators-as-protocol-witnesses.md)

---

### SE-0241: Implicit Return from Single-Expression Closures

**What it is:** Closures can omit `return` if they have a single expression.

**Where Urkel uses it:**
Transition closures often use implicit returns:

```swift
let transition: @Sendable () async -> Machine<Running> = {
    // No explicit return needed
    Machine<Running>(...)
}
```

**Why it matters:** Generated code is more concise and readable.

**Reference:** [SE-0241 Adopted](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0241-string-index-explicit-bounds-checking.md)

---

### SE-0345: `if let` Shorthand for Binding Conditions

**What it is:** Simplifies optional binding in conditional statements.

**Where Urkel uses it:**
Sometimes in generated code for fallback patterns:

```swift
if let context = self?.context {
    // use context
}
```

**Reference:** [SE-0345 Adopted](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0345-if-let-shorthand.md)

---

## Prepared For (Not Yet Adopted)

### SE-0430: Transferring Parameters and Results (~transferring)

**What it is:** A marker for parameters and return values that explicitly transfer ownership across actor boundaries.

**Status:** Urkel is designed to work with this, but doesn't actively generate it yet.

**Example usage (when adopted):**
```swift
// Instead of:
public consuming func start() async -> Machine<Running>

// Could be:
public func start() async -> transferring Machine<Running>
// Explicitly marks that ownership is transferred
```

**Why it matters:** Makes ownership transfer explicit at the API level. Helps the compiler prevent Sendable violations.

**Readiness:** Urkel's move semantics are already compatible with this proposal.

**Reference:** [SE-0430 Under Review](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)

---

### SE-0432: Noncopyable Structs with Methods Using `switch consume`

**What it is:** Allows pattern matching on noncopyable types.

**Status:** Urkel is prepared for this. Not yet actively used.

**Example usage (when adopted):**
```swift
extension Machine {
    public consuming func handle() {
        switch consume self {
        case let .idle(m):
            // Handle Idle state
        case let .running(m):
            // Handle Running state
        }
    }
}
```

**Why it matters:** Makes pattern matching on noncopyable state wrappers more natural and performant.

**Current approach:** Urkel uses extension-based method dispatch instead of pattern matching.

**Readiness:** The architecture is fully compatible; adoption is pending language stabilization.

**Reference:** [SE-0432 Under Review](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md)

---

### Nonescapable Types (~Escapable)

**What it is:** Types that cannot escape the scope in which they're created (similar to `inout`).

**Status:** Urkel supports `~Escapable` but only in context-threaded mode.

**Example:**
```swift
machine Machine<Context>
// Generates: where Context: ~Escapable

// Prevents Context from being stored and outliving the transition
```

**Why it matters:** Allows stack-allocated context in some scenarios. Performance optimization.

**Current use:** Limited. Most Urkel code uses context-threaded mode when it needs context.

**Readiness:** Full support waiting for wider Swift adoption of nonescapable semantics.

---

## Not Used (But Relevant)

### SE-0291: Package Access Level Modifier

**What it is:** Allows marking declarations with `package` visibility.

**Why it's relevant:** Generated code could use `package` to hide implementation details while remaining package-visible.

**Status:** Not yet used. Future enhancement.

---

## Understanding the Syntax

### The `~Copyable` Marker

```swift
struct Machine<State>: ~Copyable {
    // This struct cannot be copied
}
```

The tilde (~) prefix means "does NOT conform to." So `~Copyable` means "does NOT conform to Copyable" (i.e., noncopyable).

**Common markers:**
- `~Copyable` = noncopyable (unique ownership)
- `~Escapable` = nonescapable (scoped lifetime)
- `~Sendable` = not sendable (contains unsendable types)

### The `consuming` Keyword

```swift
consuming func start() async -> Machine<Running> {
    // `self` is explicitly consumed
    // This function *moves* self, destroying the old value
}
```

Think of it like `inout self`, but instead of returning through the same reference, it returns a new value.

**What it prevents:**
```swift
var machine = Machine<Idle>(...)
let running = await machine.start()
machine.stop()  // ❌ ERROR: machine was consumed by start()
```

### The `borrowing` Keyword

```swift
borrowing func inspect() -> String {
    // `self` is borrowed (read-only)
    // Cannot modify or consume
    return "Current state"
}
```

This is the opposite of `consuming`. The caller retains ownership.

---

## Bridging Unfamiliar Syntax

If you're new to these features, here's a "translation table":

| Syntax | Meaning | When You See It |
|--------|---------|-----------------|
| `~Copyable` | Type cannot be copied | On noncopyable structs (like `Machine`) |
| `consuming func` | Function moves (destroys) self | Transition functions |
| `borrowing func` | Function borrows self | Read-only accessors |
| `@Sendable` | Closure is thread-safe | Transition closures |
| `async` | Function is asynchronous | All transitions |
| `await` | Call an async function | Calling transitions |
| `transferring` (upcoming) | Ownership transfers | Will appear in future APIs |
| `switch consume` | Pattern match (destroys) | Will appear in future code |

---

## Learning Resources

To deepen your understanding, explore these resources:

### Official Swift Evolution Proposals

- [SE-0426: Noncopyable Types](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0426-noncopyable-types.md)
- [SE-0431: `borrowing` and `consuming`](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0431-borrowing-and-consuming.md)
- [SE-0430: Transferring Parameters](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0430-transferring-parameters-and-results.md)
- [SE-0432: Noncopyable Switch](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0432-noncopyable-switch.md)

### Community Resources

- **Point-Free**: [Noncopyable Types](https://www.pointfree.co/) (search their archives)
- **Swift Forums**: [swift-users discussion](https://forums.swift.org/c/development)
- **Swiftology**: [Typestate Pattern in Swift](https://swiftology.io/)

### Books & Articles

- **"Concurrency in Swift"** by Kavon Farvardin (draft available online)
- **"Advanced Swift"** by Chris Eidhof, Ole Begemann, and Airspeed Velocity
- **"Protocol Oriented Programming in Swift"** by Matt Neuburg (covers generic specialization)

---

## FAQ: Advanced Syntax

### Q: Why `~Copyable` Instead of a Different Marker?

The `~` prefix follows Swift's convention for protocol non-conformance markers:
- `protocol MyType: ~Sendable { }` means "doesn't need to be Sendable"
- `struct Machine: ~Copyable { }` means "doesn't have Copyable semantics"

This is consistent and unambiguous.

### Q: What's the Difference Between `consuming` and `inout`?

| Aspect | `consuming` | `inout` |
|--------|-----------|--------|
| **Ownership** | Moves (destroys) self | Borrows self |
| **Return** | Returns new value | Modifies in-place |
| **Use case** | State transitions | Mutation |
| **Example** | `consuming func start() -> Running` | `inout func update()` |

### Q: Why Is Every Transition `async`?

State machines often involve I/O (file watching, network, timers). Making transitions async by default:
- Prevents blocking operations
- Allows natural use of `await`
- Aligns with modern Swift concurrency patterns

### Q: Can I Make a Synchronous Transition?

**Currently:** No. All transitions are `async`.

**Workaround:** Use async functions with `Task { }` blocks in synchronous contexts, or use synchronous helpers that return `AsyncThrowingStream`.

**Future:** SE-0340 (Statically Unavailable Functions) could enable conditional sync/async, but this isn't planned yet.

---

## How These Features Enable Urkel's Safety

Each feature contributes to Urkel's three-pillar safety model:

**Type-Level Safety:**
- Generic specialization (`where State == Idle`)
- Conditional conformance (`extension Machine where State == Running`)

**Memory Safety:**
- `~Copyable` (prevents duplication)
- `consuming func` (enforces linear progression)
- `borrowing` (read-only access)

**Concurrency Safety:**
- `@Sendable` closures (thread-safe)
- `async`/`await` (structured concurrency)
- `transferring` (ownership transparency) — coming

---

## Conclusion

Urkel showcases how cutting-edge Swift features can combine to create genuinely safe state machines. By using noncopyable types, move semantics, and Sendable closures, Urkel makes invalid states impossible rather than just unlikely.

As Swift evolves (SE-0430, SE-0432), Urkel will adopt new features to make this safety even more explicit and performant.

Understanding these features not only helps you use Urkel effectively, but also prepares you for modern, production-grade Swift development.

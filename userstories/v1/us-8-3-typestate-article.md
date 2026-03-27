# US-8.3: Typestate & Concurrency Architecture Article

## 1. Objective
Write a conceptual DocC article explaining the *why* behind Urkel: detailing the Typestate pattern, `~Copyable` memory safety, and how the architecture achieves strict concurrency isolation.

## 2. Context
Many iOS/macOS developers are not familiar with the Typestate pattern or Swift 5.9's noncopyable types. If they see `consuming func` and `~Copyable` in the generated code, they might be confused. This article serves as educational material, explaining how Urkel eliminates invalid states at compile time and makes Swift 6 strict concurrency checks a breeze.

## 3. Acceptance Criteria
* **Given** a developer is new to Typestate.
* **When** they read the "Architecture & Safety" article.
* **Then** they understand how encoding state into the type signature prevents calling `start()` when already `Running`.
* **And Then** they understand why `~Copyable` prevents duplicating states or accidentally dropping the machine context.
* **And Then** the article explains how Point-Free style Dependency Injection is wired into the generated `Client`.

## 4. Implementation Details
* Create `Typestate-Architecture.md`.
* Include the "Car Metaphor" (from the README) to explain runtime state chaos vs. compile-time safety.
* Provide snippets showing how the generated code handles state consumption and explicitly blocks invalid actions.

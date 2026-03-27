# Urkel User Stories

This directory contains the user stories for Urkel, organized by epic.

Previous stories are archived under [`v1/`](v1/README.md).

A complete reference of all DSL constructs mapped on trigger × scope × effect axes is in [`dsl-construct-map.md`](dsl-construct-map.md).

---

## Epic 1 — Urkel DSL

The Urkel DSL (`.urkel`) is a plain-text, arrow-notation language for declaring state machines. It is designed to be the single source of truth for a machine's structure — readable by humans, toolable by machines, and target-language agnostic.

Epic 1 covers the complete DSL specification from the ground up: starting from the smallest valid file and building all the way through guards, actions, hierarchical states, orthogonal regions, and advanced statechart features. Every story in this epic is purely about what can be written in a `.urkel` file and what it means — not about parsers, emitters, or plugins.

### Design Principles

- **Flat by default.** The `@states` and `@transitions` blocks read like tables, not trees. Structure is added only when needed.
- **Arrow syntax is the DNA.** Every transition is expressed as `Source -> Event -> Dest`. All extensions (guards, actions, forks) augment this line without replacing it.
- **Names in the DSL; implementations in code.** Guard names, action names, and service names are declared in `.urkel`. Their implementations are injected at construction time. The DSL never contains logic.
- **Explicit over implicit.** Failure paths, fallback branches, and side effects are declared, not inferred.
- **Bring Your Own Types (BYOT).** Event parameters, context types, and output types are normal types from the host language.

### Stories

| ID | Title | Scope |
|----|-------|-------|
| [US-1.1](us-1-1-core-machine-structure.md) | Core Machine Structure | Minimal valid `.urkel` file |
| [US-1.2](us-1-2-typed-event-parameters.md) | Typed Event Parameters | Event payloads |
| [US-1.3](us-1-3-init-state-parameters.md) | Init State Parameters | Construction-time inputs on `init` |
| [US-1.4](us-1-4-doc-comments.md) | Doc Comments | `#` comment pass-through |
| [US-1.5](us-1-5-final-state-output.md) | Final State Typed Output | Terminal values |
| [US-1.6](us-1-6-guards.md) | Guards | Conditional branching |
| [US-1.7](us-1-7-actions.md) | Actions | Side effects |
| [US-1.8](us-1-8-internal-and-wildcard-transitions.md) | Internal Transitions | `-*>` effect modifier |
| [US-1.9](us-1-9-eventless-transitions.md) | Eventless Transitions | `always` |
| [US-1.10](us-1-10-compound-states.md) | Compound States | Hierarchical (HSM) |
| [US-1.11](us-1-11-history-states.md) | History States | `@history` modifier |
| [US-1.12](us-1-12-parallel-regions.md) | Parallel Regions | `@parallel`, `@on P.Region::State`, `@on P::done` |
| [US-1.13](us-1-13-machine-composition.md) | Machine Composition | `@import`, fork `=>`, `@on` reactions |
| [US-1.14](us-1-14-async-loading-pattern.md) | Async Loading Pattern | `@entry`/`@exit` convention for async ops |
| [US-1.15](us-1-15-delayed-transitions.md) | Delayed Transitions | `after(duration)` |
| [US-1.16](us-1-16-continuation-transitions.md) | Stream Production Pattern | `@entry`/`@exit` convention for producers |
| [US-1.17](us-1-17-compound-reactive-conditions.md) | Compound Reactive Conditions | Multi-condition `@on` AND joins |
| [US-1.18](us-1-18-wildcard-source.md) | Wildcard Source | `*` scope sugar for caller-driven transitions |

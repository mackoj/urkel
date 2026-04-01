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
| [US-1.19](us-1-19-state-carried-data.md) | State-Carried Data | `state Name(params)` — typed data on any state kind |
| [US-1.20](us-1-20-invariants.md) | Machine Invariants | `@invariants` block — structural graph properties |

---

## Epic 2 — Parser

The parser turns `.urkel` source text into a `UrkelFile` AST using
`pointfreeco/swift-parsing`. Because every combinator conforms to
`ParserPrinter`, the pipeline is **bidirectional**: parsing goes text → AST
and printing goes AST → canonical `.urkel` text. A semantic validation pass
built on top of the AST catches logical errors (unreachable states, missing
`init`, broken references) with precise source locations.

### Design Principles

- **Grammar-mirrored.** Each EBNF rule in `grammar.ebnf` becomes a named Swift
  combinator. Reading the code and reading the grammar feel identical.
- **Bidirectional.** Every combinator conforms to `ParserPrinter`; the printer
  is not a separate implementation.
- **Diagnostics over exceptions.** The validator returns `[Diagnostic]` — errors
  and warnings with source ranges — rather than throwing on the first failure.
- **BYOT boundary.** Type expressions are opaque strings; the validator never
  resolves host-language types.

### Stories

| ID | Title | Scope |
|----|-------|-------|
| [US-2.1](us-2-1-swift-parsing-integration.md) | swift-parsing Integration & Lexical Primitives | Package dep, whitespace, identifier, TypeExpr, doc comments |
| [US-2.2](us-2-2-states-parsers.md) | States Block Parsers | ParameterList, StateKind, history, simple/compound states |
| [US-2.3](us-2-3-transitions-parsers.md) | Transitions Block Parsers | Arrows, events, timers, guards, actions, forks, reactive stmts |
| [US-2.4](us-2-4-full-file-parser-validation.md) | Full File Parser & Semantic Validation | `UrkelParser`, `UrkelValidator`, `Diagnostic`, all validation rules |
| [US-2.5](us-2-5-bidirectional-printing.md) | Bidirectional Printing | `ParserPrinter` conformance, `UrkelPrinter`, `urkel format` CLI |

---

## Epic 3 — AST

The Abstract Syntax Tree is the in-memory representation of a parsed `.urkel`
file. It is the single source of truth for the validator, emitter, and
visualiser. Epic 3 defines the complete typed model for every v2 grammar
construct, with source-range metadata for IDE tooling.

### Stories

| ID | Title | Scope |
|----|-------|-------|
| [US-3.1](us-3-1-ast-core.md) | Core AST Model | `UrkelFile`, `ImportDecl`, `Parameter`, `DocComment` |
| [US-3.2](us-3-2-ast-extended.md) | Extended AST Nodes | Compound states, parallel regions, transitions, reactive stmts |
| [US-3.3](us-3-3-ast-source-ranges.md) | Source Range Tracking | `SourceLocation`, `SourceRange`, equality ignores ranges |

---

## Epic 4 — Visualization

The visualizer renders any `.urkel` file as an interactive, live-updating
statechart diagram in VS Code. It surfaces validator diagnostics as visual
highlights, supports interactive simulation (step through transitions without
running any Swift code), and provides a CLI path explorer that enumerates all
`init → final` paths and generates Swift test stubs.

### Stories

| ID | Title | Scope |
|----|-------|-------|
| [US-4.1](us-4-1-vscode-visualizer.md) | VS Code Statechart Visualizer | WebviewPanel, elkjs layout, SVG render, click-to-navigate |
| [US-4.2](us-4-2-live-validation-highlighting.md) | Live Validation Highlighting | Dead/unreachable highlights, Problems panel, `urkel validate --json` |
| [US-4.3](us-4-3-simulate-mode.md) | Simulate Mode | Step-through, guard toggles, history timeline, path export |
| [US-4.4](us-4-4-cli-path-explorer.md) | CLI Path Explorer & Test Stubs | `urkel paths`, `urkel test-stubs`, Mermaid output |

---

### DSL Construct Reference

[`CONSTRUCTS.md`](CONSTRUCTS.md) — complete trigger × scope × effect reference table.

### Known Gaps — Status

| Gap | Description | Status |
|-----|-------------|--------|
| GAP-1 | State-carried data on non-final/non-init states | ✅ Resolved — US-1.19 |
| GAP-2 | Fork `=>` cannot pass params to sub-machine constructor | ✅ Resolved — US-1.13 `ForkBinding` |
| GAP-3 | No `[else]` guard fallback | ✅ Already in US-1.6 |
| GAP-4 | Output events not observable by parent via `@on` | ✅ By design — resolved by GAP-1 pattern; see US-1.13 Notes |
| GAP-5 | Dot notation needed in `@entry`/`@exit` for compound sub-states | ✅ Already in v2 grammar via `StateRef` |
| GAP-6 | Evaluation order of `always ->` vs `-*> always` | ✅ Resolved — US-1.9 criterion + Notes |
| GAP-7 | `after()` cannot supply params to a param-carrying destination state | ✅ Resolved — `after(Ns, param: Type)` added to `TimerDecl` in grammar |
| GAP-8 | Multiple output event stream lifecycle is implicit | ✅ Not a gap — `@exit State / stopStream` action closes the stream |
| GAP-10 | Duplicate output event declarations across sibling states | ✅ Resolved by compound state pattern — declare output event once on parent |

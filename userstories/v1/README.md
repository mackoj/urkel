# User Stories Table of Contents

This directory contains the implementation stories for Urkel, grouped by epic.

## Epic 1 — Foundation

- [ ][US-1.1 foundation](us-1-1-foundation.md)
- [ ][US-1.2 base file pipeline](us-1-2-base.md)

## Epic 2 — AST and Parsing

- [ ][US-2.1 AST model](us-2-1-ast.md)
- [ ][US-2.2 parser](us-2-2-parser.md)
- [ ][US-2.3 swift-parsing refactor](us-2-3-swift-parsing.md)

## Epic 3 — Validation

- [ ][US-3.1 validator](us-3-1-validator.md)
- [ ][US-3.2 semantic validation](us-3-2-semval.md)

## Epic 4 — Emitter and Generated Runtime

- [ ][US-4.1 generator](us-4-1-generator.md)
- [ ][US-4.2 transitions](us-4-2-transitions.md)
- [ ][US-4.3 client](us-4-3-client.md)
- [ ][US-4.4 runtime scaffolding](us-4-4-runtime-scaffolding.md)
- [ ][US-4.5 namespaced typed context](us-4-5-namespaced-typed-context.md)
- [ ][US-4.6 doc comment pass-through](us-4-6-comment-passthrough.md)

## Epic 5 — File Watching, SPM, and Checked-in Generation

- [ ][US-5.1 folder watching](us-5-1-folder-watching.md)
- [ ][US-5.2 SPM plugin](us-5-2-spm.md)
- [ ][US-5.3 external generation configuration](us-5-3-external-plugin-configuration.md)
- [ ][US-5.4 checked-in generated source workflow](us-5-4-command-plugin-generated-source.md)

## Epic 6 — LSP

- [ ][US-6.1 LSP server](us-6-1-lsp.md)
- [ ][US-6.2 VS Code protocol support](us-6-2-vscode-lsp-protocol.md)
- [ ][US-6.3 editor features](us-6-3-lsp-editor-features.md)

## Epic 7 — Export and Templates

- [ ][US-7.1 Mustache export](us-7-1-mustache.md)
- [ ][US-7.2 BYOL custom templates](us-7-2-byol.md)
- [ ][US-7.2 bundled Kotlin template](us-7-2-kotlin.md)

## Epic 8 — Documentation

- [ ][US-8.1 DocC foundation](us-8-1-docc.md)
- [ ][US-8.2 language specification guide](us-8-2-urkel-spec-doc.md)
- [ ][US-8.3 typestate architecture article](us-8-3-typestate-article.md)
- [ ][US-8.4 templating guide](us-8-4-templating.md)
- [ ][US-8.5 interactive tutorial](us-8-5-tutorial.md)
- [ ][US-8.6 generated file integration](us-8-6-generated-file-integration.md)

## Epic 9 — FSM Decoupling

- [ ][US-9.1 generic FSM scaffold](us-9-1-fsm-scaffold.md)
- [ ][US-9.2 lifecycle context storage](us-9-2-lifecycle-context-storage.md)
- [ ][US-9.3 dependency client boilerplate](us-9-3-dependency-client-boilerplate.md)
- [ ][US-9.4 runtime stream helpers](us-9-4-runtime-stream-helpers.md)
- [ ][US-9.5 domain boundaries](us-9-5-domain-boundaries.md)

## Epic 10 — Reliability, Expressiveness, and Tooling Quality

- [ ][US-10.1 zero-arg factory closure emission](us-10-1-factory-zero-arg-closure-emission.md)
- [ ][US-10.2 full Swift context types in machine declaration](us-10-2-parser-full-swift-context-types.md)
- [x][US-10.3 richer semantic validation rules](us-10-3-validator-richer-semantic-rules.md)
- [x][US-10.4 CLI/plugin/watch configuration parity](us-10-4-plugin-watch-config-parity.md)
- [x][US-10.5 template model expansion and Kotlin parity](us-10-5-template-model-and-kotlin-parity.md)
- [x][US-10.6 LSP performance and partial-AST resilience](us-10-6-lsp-performance-and-partial-ast.md)

## Epic 11 — Composition and Forking

- [ ][US-11.1 fork operator and composition AST](us-11-1-fork.md)
- [ ][US-11.2 orchestrator actor emitter](us-11-2-orchestrator.md)

## Epic 12 — Statechart DSL v2

- [ ][US-12.1 guards — conditional transitions](us-12-1-guards.md)
- [ ][US-12.2 actions — entry, exit, and transition side effects](us-12-2-actions.md)
- [ ][US-12.3 compound (nested/hierarchical) states](us-12-3-compound-states.md)
- [ ][US-12.4 parallel states (orthogonal regions)](us-12-4-parallel-states.md)
- [ ][US-12.5 internal transitions and wildcard sources](us-12-5-internal-transitions-wildcards.md)
- [ ][US-12.6 history states (`@history`)](us-12-6-history-states.md)
- [ ][US-12.7 eventless / automatic transitions (`always`)](us-12-7-eventless-transitions.md)
- [ ][US-12.8 final state output data](us-12-8-final-state-output.md)

## Epic 13 — Visualizer, Simulator & Inspector

- [ ][US-13.1 VS Code statechart visualizer](us-13-1-visualizer.md)
- [ ][US-13.2 VS Code simulate mode](us-13-2-simulate-mode.md)
- [ ][US-13.3 CLI path explorer and machine linter](us-13-3-cli-path-explorer.md)
- [ ][US-13.4 generated Swift test path stubs](us-13-4-generated-test-stubs.md)
- [ ][US-13.5 runtime trace protocol](us-13-5-runtime-trace-protocol.md)

## Epic 14 — Advanced State Behaviors

- [ ][US-14.1 `@invoke` — async operations as first-class state semantics](us-14-1-invoke.md)
- [ ][US-14.2 delayed transitions (`after(duration)`)](us-14-2-delayed-transitions.md)

## Epic 15 — Cross-Package Machine Import

- [ ][US-15.1 unified `@import` — replace `@compose` with a single import keyword](us-15-1-cross-package-import.md)

## Epic 16 — Formal Verification & Test Excellence

- [ ][US-16.1 formal property verification (`@assert`)](us-16-1-formal-verification.md)
- [ ][US-16.2 `UrkelTestSupport` — test helpers library](us-16-2-test-support-library.md)

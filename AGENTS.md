# Agent notes

Urkel is a DSL and compiler: `.urkel` files describe state machines, and the compiler generates compile-time safe
typestate Swift (`~Copyable` machines with `consuming` transitions) plus a swift-dependencies client. Products and
their dependencies are in `Package.swift`; the language is in `userstories/grammar.ebnf` and
`Sources/Urkel/Urkel.docc/Language-Spec.md`; usage is in `README.md`.

Read `CODING_STANDARDS.md` before writing code.

## Build and test

- `swift build --build-tests` and `swift test`; one suite with `swift test --filter <Suite>`.
- CI (`.github/workflows/ci.yml`) builds and tests on macOS and runs the architecture rules.
- Architecture rules: `swift test --package-path Architecture` (macOS only) runs the mechanical part of
  `CODING_STANDARDS.md` as [swift-llm-check](https://github.com/mackoj/swift-llm-check) rules, listed in
  `docs/architecture-rules.md`. A failure prints the rule, why it exists and how to fix it: fix the code, never add
  a baseline. A new or changed rule needs its rationale and bad and good examples, a `DetectorTests` case, and
  `LLM_CHECK_RECORD=1 swift test --package-path Architecture` to regenerate the document.

## Docs travel with code

- `README.md` is the user documentation; DocC lives in `Sources/Urkel/Urkel.docc`.

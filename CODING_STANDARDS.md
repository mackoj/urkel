# Coding standards

Read during review. The mechanical rules are enforced by `swift test --package-path Architecture` and listed in
[`docs/architecture-rules.md`](docs/architecture-rules.md); the rest are judgement calls.

## Module layering

- **One job per module.** `UrkelAST` (plain data, no dependencies) → `UrkelParser` (swift-parsing) →
  `UrkelValidation` → `UrkelEmitterSwift` (swift-syntax) / `UrkelEmitterMustache` (swift-mustache) /
  `UrkelVisualize`. The umbrella `Urkel` module orchestrates them and owns configuration, the generator, the watch
  service and the language server; `UrkelCLI`, `UrkelLSP` and the plugins sit on top.
- **Imports follow `Package.swift`.** A module imports only Foundation and the dependencies its target declares. A
  sibling never imports a sibling (validation does not parse; the emitter does not validate).
- **Swift output goes through `UrkelEmitterSwift`; every other language through a Mustache template.**

## Pure pipeline

- **Text in, values out.** The AST, parser, validator, Swift emitter and visualiser take a `String` or a `UrkelFile`
  and return a value. They read no files, spawn no processes, read no clock and never `print`. File system work
  belongs to `UrkelGenerator`, `UrkelConfiguration` and the CLI.
- **Deterministic output.** The same `.urkel` source produces byte-identical Swift. Order comes from the source
  (arrays, first-seen order), never from a `Set` or `Dictionary` iteration.

## Errors are values

- **Throw, don't trap.** Parse failures throw `UrkelParseError` with a line; semantic problems are `Diagnostic`s
  with a `DiagnosticCode`; emitter failures throw `SwiftSyntaxEmitterError`. No `try!`, `as!`, `fatalError` or
  `precondition` in library code: it runs inside a client's build, editor and tests.
- **Generated code is checked.** The Swift emitter parses everything it writes with SwiftParser before returning it.

## The AST is plain data

- **Values.** Every public `UrkelAST` type is a `struct` or `enum`, `Equatable`, `Sendable` and `Codable`, so the
  parser's round-trip tests compare whole trees and the language server can share them across tasks.
- **Grammar first.** A new construct starts in `userstories/grammar.ebnf` and a user story, then the AST, the parser
  and its printer (round trip), the validator, and the emitters.

## Tests

- **Swift Testing only.** `@Suite`, `@Test`, `#expect`, `#require`; no XCTest.
- **No silenced tests.** No `.disabled`; a known issue says what it is and where it is tracked.
- **Emitter changes are visible.** Generated Swift is covered by inline snapshots; an intended change to the output
  updates the snapshot in the same change.

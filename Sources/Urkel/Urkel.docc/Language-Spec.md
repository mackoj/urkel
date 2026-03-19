# Urkel Language Specification

This article describes the `.urkel` format in practical terms.

## Core sections

- `@imports` declares the Swift imports needed by the generated file.
- `@factory` names the initializer/factory method for the generated client.
- `@states` defines the typestate markers.
- `@transitions` defines the legal state transitions.

## Example

```text
@imports
  import Foundation
  import Dependencies

machine FolderWatch<FolderWatchContext>
@factory makeObserver(directory: URL, debounceMs: Int)

@states
  init Idle
  state Running
  final Stopped

@transitions
  Idle -> start -> Running
  Running -> stop -> Stopped
```

## BYOT

Urkel follows a Bring Your Own Types approach. Your payloads, context types, and transition parameters can be normal Swift types such as `URL`, `Int`, or your own structs and actors.

## Validation rules

The parser and validator reject malformed transitions, invalid state references, and machines that do not define a valid initial state.

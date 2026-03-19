# Generated Runtime API

Urkel emits a small runtime surface around each machine so applications can move from one state to another without editing generated code directly.

## The generated pieces

- A machine namespace that contains the typestate markers.
- A `FolderWatchObserver<State>`-style observer wrapper that consumes state transitions.
- A `FolderWatchState`-style wrapper enum that makes the observer ergonomics pleasant.
- A dependency client that exposes `testValue`, `previewValue`, and `liveValue`.

## Why the namespace matters

Generated state markers are machine-scoped, which means multiple generated machines can live in the same module without colliding on `Idle`, `Running`, or `Stopped`.

For example, a `FolderWatch` machine uses `FolderWatchMachine.Idle`, `FolderWatchMachine.Running`, and `FolderWatchMachine.Stopped`.

## How runtime context flows

When the `.urkel` file does not declare an explicit context type, Urkel emits a machine-scoped `RuntimeContext` so generated transition plumbing still stays typed.

When a machine does declare a context type, the generated observer keeps that type through the transition closures.

## Recommended integration pattern

Keep the generated file read-only and move runtime logic into sidecar files:

- `MachineClient+Runtime.swift`
- `MachineClient+Live.swift`
- `MachineClient+Test.swift`

That way, regeneration only updates the generated interface while your custom implementation remains stable.

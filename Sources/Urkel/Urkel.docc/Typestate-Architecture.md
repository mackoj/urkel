# Typestate Architecture

Urkel’s generated code encodes state in the type system so invalid transitions become compile-time errors.

## Why this matters

Instead of a single enum or a pile of booleans, each state becomes a distinct type. That means a method like `start()` can exist only on the `Idle` state, and `stop()` can exist only on the `Running` state.

## Memory and concurrency benefits

The generated runtime uses `~Copyable` wrappers and consuming methods to make state progression linear. That helps prevent duplicate state usage and keeps async workflow boundaries explicit.

## Mental model

Think of the machine like a car:

- `Idle` is parked and ready.
- `Running` is moving.
- `Stopped` is parked again, but after the machine has progressed through its workflow.

The compiler enforces that you can only call the actions that make sense for the current state.

# US-1.3: Init State Parameters

## Objective

Allow the `init` state to carry named, typed parameters that are supplied once at construction time and available for the lifetime of the machine — making dependency injection an intrinsic part of the state declaration rather than a separate top-level keyword.

## Background

A state machine is only as useful as the dependencies it can reach — a folder-watcher needs a directory URL and a debounce interval; a BLE machine needs a device filter; a networking machine needs a base URL. These values are provided once when the machine is created, not with each event.

Rather than a separate `@factory` declaration, Urkel attaches construction parameters directly to the `init` state. This is semantically precise: entering the initial state IS the act of constructing the machine, so the parameters belong there. The `init` state name and its parameters together fully describe what is needed to start the machine.

Machines that need no construction-time inputs declare `init` without parameters — the baseline syntax from US-1.1 is unchanged.

Construction parameters are distinct from event parameters (US-1.2): they are fixed for the machine's lifetime (available in the context), whereas event parameters travel with individual transitions.

## DSL Syntax

```
machine FolderWatch

@states
  init(directory: URL, debounceMs: Int) Idle
  state Running
  final Stopped

@transitions
  Idle    -> start -> Running
  Running -> stop  -> Stopped
```

### No parameters (unchanged from US-1.1)

```
machine Counter

@states
  init Zero
  state Counting
  final Done

@transitions
  Zero     -> increment -> Counting
  Counting -> increment -> Counting
  Counting -> finish    -> Done
```

### With context type and parameters

```
machine BLE: BLEContext

@states
  init(filter: DeviceFilter, timeoutMs: Int) Off
  state Scanning
  state Connected
  final PoweredDown

@transitions
  Off       -> powerOn  -> Scanning
  Scanning  -> found    -> Connected
  Connected -> powerOff -> PoweredDown
```

### Multiple parameters

```
machine HTTPClient: HTTPContext

@states
  init(baseURL: URL, session: URLSession, retryLimit: Int) Idle
  state Active
  final Closed

@transitions
  Idle   -> send(request: URLRequest) -> Active
  Active -> response(data: Data)      -> Idle
  Idle   -> close                     -> Closed
```

## Acceptance Criteria

* **Given** `init(directory: URL, debounceMs: Int) Idle`, **when** processed, **then** the `init` state is declared with construction parameters `directory: URL` and `debounceMs: Int` — these are the required inputs to create the machine.

* **Given** `init Idle` with no parameter list, **when** processed, **then** the machine has no construction-time inputs — valid and unchanged from US-1.1.

* **Given** construction parameters on any state other than `init` (`state(foo: Bar) Running`), **when** validated, **then** an error is emitted: `"Construction parameters are only valid on the 'init' state"`.

* **Given** a machine with context type `machine Foo: FooContext` and init parameters, **when** processed, **then** both are valid together — the context type and the init parameters are independent declarations.

* **Given** parameter types that are complex host-language types (e.g., `@escaping (Error) -> Void`, `[String: Any]`), **when** processed, **then** the type string is taken verbatim — the DSL does not parse or validate it.

* **Given** an `init` state in a compound state's child position (US-1.10), **when** validated, **then** construction parameters are **not** valid on child `init` states — only on the machine's top-level `init`; an error is emitted if attempted.

## Grammar

```ebnf
StateStmt     ::= StateKind InitParams? Identifier Newline
StateKind     ::= "init" | "state" | "final"
InitParams    ::= "(" ParameterList ")"
ParameterList ::= Parameter ("," Parameter)*
Parameter     ::= Identifier ":" SwiftType
```

`InitParams` is syntactically permitted on any `StateKind` but the validator enforces it only on the top-level `init` state.

## Notes

- Construction parameter names become argument labels on the generated initializer. Choose names that read well at the call site.
- The generated return type of the initializer is always the machine client — it is never written in the DSL.
- Parameters appear between the `init` keyword and the state name: `init(params) StateName`. This order — kind, inputs, name — reads naturally: "start with these inputs in state `Idle`".

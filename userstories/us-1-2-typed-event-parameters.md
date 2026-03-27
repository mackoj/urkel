# US-1.2: Typed Event Parameters

## Objective

Allow transition events to carry named, typed payloads — values the caller must supply when sending an event and that travel with the transition.

## Background

Most real events carry data: a file URL, a device handle, an error, a measurement. Without typed parameters, this data must live in the context and be mutated before firing an event, which couples the caller to internal implementation details.

Urkel follows a **Bring Your Own Types (BYOT)** philosophy: parameter types are normal host-language types (Swift structs, enums, protocols — whatever the caller already has). The DSL names the parameter and specifies its type; it never defines or constrain what that type looks like.

Parameters are part of the event's identity: `connect` and `connect(device: BLEDevice)` are different events.

## DSL Syntax

```
machine BLE: BLEContext

@states
  init Off
  state Scanning
  state Connecting
  state Connected
  state Error
  final PoweredDown

@transitions
  Off        -> powerOn                           -> Scanning
  Scanning   -> deviceFound(device: BLEDevice)    -> Connecting
  Scanning   -> scanTimeout                       -> Error
  Connecting -> connectionFailed(reason: String)  -> Error
  Connecting -> connectionEstablished             -> Connected
  Connected  -> dataReceived(payload: Data)       -> Connected
  Error      -> reset                             -> Off
  Connected  -> powerDown                         -> PoweredDown
```

### Multiple parameters

```
@transitions
  Idle -> configure(host: String, port: Int, tls: Bool) -> Connecting
```

## Acceptance Criteria

* **Given** `event(label: Type)` on a transition, **when** processed, **then** the event is treated as distinct from an event of the same name with different or no parameters.

* **Given** multiple parameters `event(a: TypeA, b: TypeB)`, **when** processed, **then** all parameters are captured as an ordered list; each must have a label and a type.

* **Given** a parameter type that contains spaces or generics (e.g., `[String: Any]`, `Optional<URL>`), **when** the DSL is processed, **then** the type string is taken verbatim and validated by the host language — the DSL does not parse or validate type expressions.

* **Given** two transitions from the same source with the same event name but different parameter signatures, **when** validated, **then** an error is emitted: `"Ambiguous event 'eventName' from state 'X': parameter signatures must match"`.

* **Given** a transition with an event that has parameters and that event is used on a wildcard source (`*`) (US-1.8), **when** validated, **then** the same parameter constraint applies to all expanded source states.

* **Given** a self-transition `Playing -> dataReceived(payload: Data) -> Playing`, **when** processed, **then** it is valid — a state may transition to itself.

## Grammar

```ebnf
TransitionStmt ::= Identifier "->" EventDecl "->" Identifier Newline
EventDecl      ::= Identifier ("(" ParameterList ")")?
ParameterList  ::= Parameter ("," Parameter)*
Parameter      ::= Identifier ":" Type
Type           ::= (any non-newline characters forming a valid host-language type)
```

## Notes

- Parameter labels are part of the public API of the generated machine. Choose them with care — they appear as argument labels on the generated transition methods.
- A parameter-less event `powerOn` and a parameterized event `powerOn(reason: String)` are considered different events. Do not reuse the same event name with different arities.

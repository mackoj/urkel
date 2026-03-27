# US-1.5: Final State Typed Output

## Objective

Allow `final` states to carry named, typed output fields — values the machine produces when it terminates — making the machine's result an explicit, type-safe part of its contract.

## Background

Many machines represent operations with a well-defined result: a login flow produces a `User`, a payment flow produces a `Receipt`, a file upload produces a `URL`. Without typed output, callers must read the result from the context as a side effect, which couples them to implementation details and loses type safety.

When a `final` state declares output parameters, the machine becomes a typed producer: it was started with certain inputs (factory parameters) and it terminates with a typed result embedded in the final state value. The transition that enters the final state is responsible for supplying the output fields — the event parameters become the output.

`final` states without output parameters continue to behave as before (US-1.1): they are pure terminal markers with no associated value.

## DSL Syntax

```
machine Login

@states
  init Idle
  state Authenticating
  # Typed output: the logged-in user
  final Success(user: User)
  # Typed output: the failure reason
  final Failure(error: AuthError)
  # No output: user cancelled, nothing to report
  final Cancelled

@transitions
  Idle          -> submit(credentials: Credentials) -> Authenticating
  Authenticating -> loginSucceeded(user: User)       -> Success
  Authenticating -> loginFailed(error: AuthError)    -> Failure
  Idle          -> cancel                            -> Cancelled
  Authenticating -> cancel                           -> Cancelled
```

### Multiple output fields

```
@states
  final Complete(report: Report, duration: TimeInterval)

@transitions
  Running -> finish(report: Report, duration: TimeInterval) -> Complete
```

## Acceptance Criteria

* **Given** `final Success(user: User)`, **when** processed, **then** `Success` is declared as a terminal state carrying a named field `user` of type `User`.

* **Given** a `final` state with no parentheses (`final Cancelled`), **when** processed, **then** it is a plain terminal state with no output — identical to the baseline behaviour from US-1.1.

* **Given** a transition targeting a `final` state with output parameters, **when** the transition's event parameters exactly match the output field names and types, **then** the transition is valid.

* **Given** a transition targeting `final Success(user: User)` whose event does not supply a `user: User` parameter, **when** validated, **then** an error is emitted: `"Transition to 'Success' must supply output field 'user: User'"`.

* **Given** output parameters declared on a `state` (non-final), **when** validated, **then** an error is emitted: `"Output parameters are only valid on 'final' states"`.

* **Given** multiple `final` states with different output types in the same machine, **when** processed, **then** each is independent — the caller can distinguish them and access their respective typed output.

* **Given** a `final` state with output that has no incoming transition, **when** validated, **then** a warning is emitted: `"Final state 'Success' is unreachable"`.

## Grammar

```ebnf
StateStmt    ::= StateKind Identifier OutputParams? Newline
OutputParams ::= "(" ParameterList ")"
ParameterList ::= Parameter ("," Parameter)*
Parameter    ::= Identifier ":" SwiftType
```

`OutputParams` is only syntactically permitted when `StateKind` is `final`; the validator enforces this constraint.

## Notes

- The output parameter names and types must exactly match the event parameters of every transition that leads to the final state. This matching is validated semantically, not by the parser.
- Output types, like event parameter types, are verbatim host-language type strings — the DSL does not inspect them.

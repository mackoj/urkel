# US-5.4: Final State Output

## Objective

Emit typed read-only properties on terminal-phase machines when the `final`
state declares output parameters (US-1.5). The generated API makes the machine's
result a first-class Swift value, accessible without casting or consulting the
context.

## Background

`final Success(user: User)` declares that the machine produces a `User` value
when it terminates successfully. Without typed output, callers must extract the
result from the context — coupling them to internal implementation. With typed
output the generated code guarantees, at the type level, that `.user` is
accessible only after the machine is in the `Success` phase.

## Input DSL

```
machine Login: LoginContext

@states
  init Idle
  state Authenticating
  final Success(user: User)
  final Failure(error: AuthError)
  final Cancelled

@transitions
  Idle          -> submit(credentials: Credentials) -> Authenticating
  Authenticating -> loginSucceeded(user: User)       -> Success
  Authenticating -> loginFailed(error: AuthError)    -> Failure
  *             -> cancel                            -> Cancelled
```

## Generated Output (delta from US-5.2)

The machine struct gains an internal `_outputData: _LoginOutputData` slot:

```swift
// Internal — not part of the public API
private enum _LoginOutputData: Sendable {
    case none
    case success(user: User)
    case failure(error: AuthError)
}
```

The transition into each final-with-output state captures the data:

```swift
extension LoginMachine where Phase == LoginPhase.Authenticating {
    public consuming func loginSucceeded(user: User) async throws -> LoginMachine<LoginPhase.Success> {
        let next = try await _loginSucceeded(_context, user)
        return LoginMachine<LoginPhase.Success>(
            _context: next,
            _outputData: .success(user: user),
            // … closures …
        )
    }
}
```

Each output parameter is exposed as a `borrowing` property on the terminal phase:

```swift
extension LoginMachine where Phase == LoginPhase.Success {
    /// The logged-in user — available only in the `Success` phase.
    public borrowing var user: User {
        guard case .success(let user) = _outputData else {
            preconditionFailure("Emitter invariant violated: in Success phase but outputData is \(_outputData)")
        }
        return user
    }
}

extension LoginMachine where Phase == LoginPhase.Failure {
    public borrowing var error: AuthError {
        guard case .failure(let error) = _outputData else {
            preconditionFailure("Emitter invariant violated: in Failure phase but outputData is \(_outputData)")
        }
        return error
    }
}
// LoginPhase.Cancelled has no output params — no properties emitted.
```

## Acceptance Criteria

* **Given** `final Success(user: User)`, **when** emitted, **then** the generated
  `LoginMachine<LoginPhase.Success>` has a `public borrowing var user: User`.

* **Given** `final Cancelled` (no params), **when** emitted, **then** no
  properties are generated on `LoginMachine<LoginPhase.Cancelled>`.

* **Given** a transition `loginSucceeded(user: User) -> Success`, **when**
  emitted, **then** the generated transition method captures `user` into
  `_outputData` before constructing the next machine.

* **Given** the `_LoginOutputData` enum, **when** the machine is in `Success`
  and `.user` is accessed, **then** it returns the value captured at transition
  time — no context lookup required.

* **Given** `final Complete(report: Report, duration: TimeInterval)` (multiple
  output fields), **when** emitted, **then** both `report` and `duration` are
  exposed as separate `borrowing var` properties on the terminal phase.

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- Add `_outputData` as a `fileprivate` stored property on `XxxMachine`.
- Generate `private enum _XxxOutputData: Sendable { case none; case stateX(fields…); … }`.
- Only generate `_outputData` when at least one `final` state has params.
- Use `preconditionFailure` (not `fatalError`) so the message is preserved in
  release builds while still crashing fast on emitter bugs.

## Testing Strategy

* Snapshot-test `stateMachine` for the Login fixture.
* Assert `_LoginOutputData` enum exists in the output.
* Assert `borrowing var user: User` exists in the extension constrained to
  `LoginPhase.Success`.
* Assert `LoginPhase.Cancelled` extension has no stored property accessors.
* Construct a noop login machine, call `loginSucceeded(user:)`, and assert
  `.user` returns the provided value.

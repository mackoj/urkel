# US-1.4: Doc Comments

## Objective

Allow `#`-prefixed comment lines in `.urkel` files to serve as documentation — either as plain inline notes or as doc comments that are preserved and forwarded to the generated output.

## Background

A state machine definition is most useful when it is self-documenting. Engineers reading a generated file should be able to understand what each transition does without consulting external documentation.

Urkel uses `#` as its comment character. A `#` line placed **immediately above** a state declaration or a transition is a **doc comment**: it is preserved in the AST and emitted as a documentation comment (`///` in Swift, `/**` in Kotlin, etc.) on the corresponding generated declaration.

A `#` line placed anywhere else — on a blank line, between unrelated declarations, or at the end of a structural line — is a **plain comment**: it aids readability in the `.urkel` source but is discarded during processing.

## DSL Syntax

```
machine BLE: BLEContext

@states
  # The BLE radio is powered off.
  init Off

  # Actively scanning for peripherals.
  state Scanning

  # Gracefully powered down.
  final PoweredDown

@transitions
  # Power on the BLE radio and begin scanning.
  Off -> powerOn -> Scanning

  # A peripheral was found; attempt to connect.
  Scanning -> deviceFound(device: BLEDevice) -> Connecting

  # Scan window elapsed without finding a device.
  Scanning -> scanTimeout -> Error
```

### Multi-line doc comments

Consecutive `#` lines immediately above a declaration are joined into a single doc comment block:

```
@transitions
  # Initiates the payment flow.
  # Only valid when the cart is non-empty and a payment method is on file.
  # Emits a `processingStarted` analytics event before returning.
  Cart -> checkout -> Processing
```

### Plain (non-doc) comments

```
@transitions
  # ── Blending states ──────────────────────────────────────────
  ConnectedWithBowl -> startBlendSlow   -> BlendSlow
  ConnectedWithBowl -> startBlendMedium -> BlendMedium

  # TODO: add high-speed mode once firmware supports it
  ConnectedWithBowl -> startBlendHigh   -> BlendHigh
```

## Acceptance Criteria

* **Given** a `#` line, **when** processed, **then** everything after `#` to end-of-line is the comment body; the `#` character itself is not included in the body.

* **Given** one or more consecutive `#` lines placed immediately before a `state` or `final` or `init` declaration (with no blank line between them), **when** processed, **then** they are captured as a doc comment on that state.

* **Given** one or more consecutive `#` lines placed immediately before a transition line (with no blank line separating them), **when** processed, **then** they are captured as a doc comment on that transition.

* **Given** a `#` line separated from the next declaration by at least one blank line, **when** processed, **then** it is treated as a plain comment and discarded — it does not attach to the declaration below.

* **Given** a `#` line on the same line as a structural declaration (e.g., `init Off # the off state`), **when** processed, **then** it is treated as a trailing plain comment — it is not emitted as a doc comment (doc comments live on their own line above).

* **Given** a file with no `#` lines, **when** processed, **then** processing succeeds — comments are entirely optional.

## Grammar

```ebnf
CommentLine  ::= "#" AnyChar* Newline
DocComment   ::= CommentLine+          (immediately preceding a StateStmt or TransitionStmt)
PlainComment ::= CommentLine           (all other positions)
```

## Notes

- Doc comments are passed through verbatim; the DSL does not enforce any markup or formatting within the comment body.
- Blank lines between two comment blocks reset the doc-comment association. Only the comments directly adjacent (no blank line gap) to the declaration attach to it.

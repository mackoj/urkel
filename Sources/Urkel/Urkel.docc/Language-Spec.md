# Urkel Language Specification

This article describes the `.urkel` format in practical terms.

## Core sections

- `machine` declares the machine name and optional context type (`machine Name<Context>`).
- `@compose` optionally declares composed machines that may be forked in transitions.
- `@factory` names the initializer/factory method for the generated client.
- `@states` defines the typestate markers.
- `@transitions` defines legal transitions, with optional forks using `=> ComposedMachine.init`.

For cross-emitter generation, prefer emitter-specific configuration in `urkel-config.json`:

```json
{
  "swiftImports": ["Foundation", "Dependencies"],
  "templateImports": ["kotlin.collections", "kotlin.io"]
}
```

This keeps `.urkel` source emitter-agnostic while letting each emitter control imports appropriately.

## Example

```text
machine FolderWatch<FolderWatchContext>
@compose Indexer
@factory makeObserver(directory: URL, debounceMs: Int)

@states
  init Idle
  state Running
  final Stopped

@transitions
  Idle -> start -> Running => Indexer.init
  Running -> stop -> Stopped
```

## BYOT

Urkel follows a Bring Your Own Types approach. Your payloads, context types, and transition parameters can be normal Swift types such as `URL`, `Int`, or your own structs and actors.

## Comments and documentation pass-through

Lines beginning with `#` are treated as DSL comments. When placed directly above a state or transition, they are preserved in the AST and emitted as Swift doc comments (`///`) above the corresponding generated declaration.

Example:

```text
# Starts the BLE radio
Idle -> start -> Scanning
```

## Validation rules

The parser and validator reject malformed transitions, invalid state references, unresolved composed-machine forks, and machines that do not define a valid initial state.

## Formal grammar

The canonical EBNF lives at repository root in `grammar.ebnf`.

Current grammar:

```ebnf
UrkelFile        ::= { TriviaLine }
                     [ MachineDecl { TriviaLine } ]
                     { ComposeDecl { TriviaLine } }
                     [ FactoryDecl { TriviaLine } ]
                     StatesBlock { TriviaLine }
                     TransitionsBlock
                     { TriviaLine }

MachineDecl      ::= { Whitespace } "machine" Whitespace Identifier [ ContextDecl ] Newline
ContextDecl      ::= "<" { Whitespace } Identifier { Whitespace } ">"
ComposeDecl      ::= { Whitespace } "@compose" Whitespace Identifier Newline
FactoryDecl      ::= { Whitespace } "@factory" Whitespace Identifier "(" [ ParameterList ] ")" Newline

StatesBlock      ::= { Whitespace } "@states" Newline { TriviaLine | StateStmt }
TransitionsBlock ::= { Whitespace } "@transitions" Newline { TriviaLine | TransitionStmt }

StateStmt        ::= { Whitespace } StateKind Whitespace Identifier { Whitespace } Newline
StateKind        ::= "init" | "state" | "final"

TransitionStmt   ::= { Whitespace } Identifier
                     { Whitespace } "->" { Whitespace }
                     EventDecl
                     { Whitespace } "->" { Whitespace }
                     Identifier
                     [ { Whitespace } "=>" { Whitespace } Identifier ".init" ]
                     { Whitespace } Newline

EventDecl        ::= Identifier [ "(" [ ParameterList ] ")" ]
ParameterList    ::= Parameter { { Whitespace } "," { Whitespace } Parameter }
Parameter        ::= Identifier { Whitespace } ":" { Whitespace } SwiftType

TriviaLine       ::= BlankLine | CommentLine
BlankLine        ::= { Whitespace } Newline
CommentLine      ::= { Whitespace } Comment Newline

Identifier       ::= Letter { Letter | Digit | "_" }
SwiftType        ::= Any valid Swift type string (e.g., "URL", "Int", "[String: Any]?")
Comment          ::= "#" { Any character except Newline }
Letter           ::= "A".."Z" | "a".."z"
Digit            ::= "0".."9"
Whitespace       ::= " " | "\t"
Newline          ::= "\n" | "\r\n"
```

For roadmap and evolution tracking tied to grammar changes, see:

- <doc:Grammar-and-User-Stories>

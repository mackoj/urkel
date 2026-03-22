# Urkel Language Specification

This article describes the `.urkel` format in practical terms.

## Core sections

- `@imports` declares import hints in the DSL (still supported).
- `@factory` names the initializer/factory method for the generated client.
- `@states` defines the typestate markers.
- `@transitions` defines the legal state transitions.

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

## Formal grammar

The canonical EBNF lives at repository root in `grammar.ebnf`.

Current grammar:

```ebnf
UrkelFile        ::= { Whitespace | Comment | Newline } 
                     [ ImportsBlock ] 
                     MachineDecl 
                     [ FactoryDecl ] 
                     StatesBlock 
                     TransitionsBlock

ImportsBlock     ::= "@imports" Newline { ImportStmt }
ImportStmt       ::= { Whitespace } "import" Whitespace SwiftType Newline

MachineDecl      ::= { Whitespace } "machine" Whitespace Identifier [ "<" Identifier ">" ] Newline

FactoryDecl      ::= { Whitespace } "@factory" Whitespace Identifier "(" [ ParameterList ] ")" Newline

StatesBlock      ::= { Whitespace } "@states" Newline { StateStmt }
TransitionsBlock ::= { Whitespace } "@transitions" Newline { TransitionStmt }

StateStmt        ::= { Whitespace } StateKind Whitespace Identifier { Whitespace } Newline
StateKind        ::= "init" | "state" | "final"

TransitionStmt   ::= { Whitespace } Identifier 
                     Whitespace? "->" Whitespace? 
                     EventDecl 
                     Whitespace? "->" Whitespace? 
                     Identifier { Whitespace } Newline

EventDecl        ::= Identifier [ "(" ParameterList ")" ]

ParameterList    ::= Parameter { "," Whitespace? Parameter }
Parameter        ::= Identifier ":" Whitespace? SwiftType

Identifier       ::= Letter { Letter | Digit | "_" }
SwiftType        ::= Any valid Swift type string (e.g., "URL", "Int", "[String: Any]?")

Letter           ::= "A".."Z" | "a".."z"
Digit            ::= "0".."9"
Whitespace       ::= " " | "\t"
Newline          ::= "\n" | "\r\n"
Comment          ::= "#" { Any character except Newline } Newline
```

For roadmap and evolution tracking tied to grammar changes, see:

- <doc:Grammar-and-User-Stories>

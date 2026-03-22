# Grammar and User Stories

This page connects two important maintenance artifacts in the Urkel repository:

- the formal grammar
- the implementation roadmap/user stories

## Formal grammar source

The canonical EBNF grammar is stored at repository root:

- `grammar.ebnf`

It defines the accepted structure of `.urkel` files, including directives and transition syntax.

## Language guide companion

For explanatory prose and examples, see:

- <doc:Language-Spec>

Use `grammar.ebnf` as the strict machine-readable source, and `Language-Spec` as the developer-readable guide.

## User stories source

Implementation and evolution work is tracked in:

- `User Stories/README.md`

Stories are grouped by epic and include:

- objective
- context
- acceptance criteria
- implementation details
- testing strategy

## How to use both together

- Update `grammar.ebnf` first when language syntax changes.
- Update parser/validator and tests to match.
- Add or update a user story describing the change and expected behavior.
- Reflect the change in <doc:Language-Spec> for public documentation.

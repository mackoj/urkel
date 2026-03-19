# Custom Templates

Urkel can export machine definitions into foreign languages using Mustache templates.

## How it works

The generator converts the parsed `MachineAST` into a dictionary-like context and feeds it into a template.

Common keys include:

- `machineName`
- `imports`
- `states`
- `transitions`

## CLI usage

Use `--template` to point at a custom template file and `--ext` to choose the output extension.

## Best practices

Keep templates deterministic, match the shape of the exported AST carefully, and prefer simple data shaping in Swift rather than complex logic in the template.

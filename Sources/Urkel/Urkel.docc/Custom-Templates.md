# Custom Templates

Urkel can export machine definitions into foreign languages using Mustache templates.

## How it works

Urkel has two generation paths from the same parsed `MachineAST`:

- `SwiftCodeEmitter`: native Swift output (`+Generated.swift`)
- `TemplateCodeEmitter`: template-based output (for example, Kotlin)

For template-based generation, `TemplateCodeEmitter` renders `MachineAST.templateContext` into your Mustache file (`.mustache`).

Common keys include:

- `machineName`
- `machineTypeName`
- `machineVariableName`
- `contextType`
- `imports`
- `states`
- `transitions`
- `groupedTransitions`
- `initialState`
- `factory`

## Bundled Kotlin template

`--lang kotlin` uses the bundled `Templates/kotlin.mustache` through `TemplateCodeEmitter`.

This means Kotlin improvements generally happen in two places:

- enrich `MachineAST.templateContext` when new data is needed
- evolve `kotlin.mustache` to consume that richer model

## CLI usage

Use `--template` to point at a custom template file and `--ext` to choose the output extension.

You can pass template-specific imports at generation time:

```bash
urkel generate machine.urkel --output out --template custom.kt.mustache --ext kt \
  --template-import kotlin.collections --template-import kotlin.io
```

The build plugins also support config-driven overrides via `urkel-config.json`:

```json
{
  "imports": {
    "kotlin": ["kotlin.collections", "kotlin.io"]
  }
}
```

## Best practices

Keep templates deterministic, match the shape of the exported AST carefully, and prefer simple data shaping in Swift rather than complex logic in the template.

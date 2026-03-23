# Build Tool Plugin Configuration

`UrkelPlugin` looks for a JSON config file named `urkel-config.json` or `.urkel-config.json` while it walks upward from each `.urkel` source file and the package root. The nearest config wins, so you can keep settings local to a feature folder or share them from the package root.

The same configuration format is also used by the `UrkelGenerate` command plugin. The difference between the plugins is where the generated file lands: the build tool plugin writes to DerivedData, while the command plugin can write back into the package directory.

## Example

```json
{
  "imports": {
    "swift": ["Foundation", "Dependencies"],
    "kotlin": ["kotlin.collections", "kotlin.io"]
  },
  "outputFile": "ConfiguredFolderWatch.swift",
  "template": "Templates/machine.mustache",
  "outputExtension": "kt",
  "sourceExtensions": ["urkel"]
}
```

## Supported keys

- `outputFile`: Full output path relative to the generator root. In build-tool mode that means the plugin work directory; in command-plugin mode it means the package directory. Use this when you want to control both the folder and the file name in one setting.
- `template`: Path to a custom Mustache template. Relative paths are resolved from the config file location.
- `language`: Use a bundled language template, currently `kotlin`.
- `imports`: Per-language imports keyed by language (for example `swift`, `kotlin`).
- `outputExtension`: Override the generated file extension.
- `sourceExtensions`: Limit which source file extensions the plugin should process. Defaults to `["urkel"]`.

Legacy keys `swiftImports` and `templateImports` are intentionally rejected with an actionable error. Replace them with `imports.swift` and `imports.<language>`.

## Notes

- `template` takes precedence over `language` because the generator uses the custom template path first.
- The config file is treated as an input, so changing it retriggers generation.
- If you want the generated file checked into `Sources/...`, use the `UrkelGenerate` command plugin instead of the build tool plugin.
- Keep generated output read-only and move custom behavior into sidecar Swift files.

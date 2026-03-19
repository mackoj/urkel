# Build Tool Plugin Configuration

`UrkelPlugin` looks for a JSON config file named `urkel-config.json` or `.urkel-config.json` while it walks upward from each `.urkel` source file and the package root. The nearest config wins, so you can keep settings local to a feature folder or share them from the package root.

## Example

```json
{
  "outputFile": "ConfiguredFolderWatch.swift",
  "template": "Templates/machine.mustache",
  "outputExtension": "kt",
  "sourceExtensions": ["urkel"]
}
```

## Supported keys

- `outputFile`: Full output path relative to the plugin work directory. Use this when you want to control both the folder and the file name in one setting.
- `template`: Path to a custom Mustache template. Relative paths are resolved from the config file location.
- `language`: Use a bundled language template, currently `kotlin`.
- `outputExtension`: Override the generated file extension.
- `sourceExtensions`: Limit which source file extensions the plugin should process. Defaults to `["urkel"]`.

## Notes

- `template` takes precedence over `language` because the generator uses the custom template path first.
- The config file is treated as an input, so changing it retriggers generation.
- Keep generated output read-only and move custom behavior into sidecar Swift files.

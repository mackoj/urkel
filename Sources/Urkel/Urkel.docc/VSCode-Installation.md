# Installing Urkel for VS Code

Urkel works best in VS Code when the editor can launch the `urkel-lsp` executable locally. You have two practical options:

1. Build the server from this checkout while developing.
2. Install a linked binary with [Mint](https://github.com/yonaskolb/Mint) so the executable lives on your PATH.

## Recommended local development flow

From the Urkel repository root:

```bash
swift build --product urkel-lsp
```

The built binary will be available at:

```bash
.build/debug/urkel-lsp
```

This repository includes `.vscode/launch.json` entries that point VS Code at the workspace build output, which is the easiest way to debug the language server while you are changing it.

## Mint-backed install

If you want a reusable local install for day-to-day editor use, Mint is a good fit.

```bash
brew install mint
mint install <your-urkel-repo>
```

Mint links installed executables into `~/.mint/bin`, so after installation you can point VS Code at:

```bash
~/.mint/bin/urkel-lsp
```

If you keep a `Mintfile`, you can also bootstrap the toolchain with `mint bootstrap` after adding the Urkel package reference there.

## VS Code setup

For local development, use the workspace build config in `.vscode/launch.json`.

For a Mint-backed install, use the linked executable path instead. In either case, the important part is that VS Code launches the local `urkel-lsp` process rather than a remote binary.

If you are integrating Urkel into a custom VS Code extension, configure the extension to spawn the executable directly and pass the current document over stdio.

# Installing Urkel in VS Code

Urkel uses two separate repositories:

- `https://github.com/mackoj/urkel` for the parser, validator, and `urkel-lsp`
- `https://github.com/mackoj/urkel-vscode-lang` for the VS Code extension that recognizes `.urkel` files

VS Code recognizes `.urkel` files as the `urkel` language, and the extension launches `urkel-lsp` over stdio while you edit.

## Recommended setup

### 1. Build `urkel-lsp`

From the Urkel repository root:

```bash
swift build --product urkel-lsp
```

That produces the local server binary at:

```bash
.build/debug/urkel-lsp
```

### 2. Install the VS Code extension

Open the VS Code extension project at `https://github.com/mackoj/urkel-vscode-lang` and open that folder in VS Code. Press `F5` to launch an Extension Development Host, or package it as a `.vsix` and install that file in VS Code.

### 3. Point the extension at the server binary

Set the language server path in workspace settings:

```json
{
  "urkel.languageServer.path": "/Users/Account/Developer/Urkel/.build/debug/urkel-lsp"
}
```

You can also use a Mint-installed binary if you prefer a PATH-based setup:

```json
{
  "urkel.languageServer.path": "~/.mint/bin/urkel-lsp"
}
```

## How to verify it is working

Open a `.urkel` file in VS Code and confirm the file is recognized as the `urkel` language. Then make a change that should trigger a diagnostic or completion. If the extension is connected correctly, the output channel should show the server starting and VS Code should receive diagnostics from `urkel-lsp`.

If you need to debug the server itself, the Urkel repository also includes `.vscode/launch.json` entries for launching `urkel-lsp` directly from the `mackoj/urkel` checkout.

## Mint-backed install

If you want a reusable local install for day-to-day editor use, Mint is a good fit:

```bash
brew install mint
mint install <your-urkel-repo>
```

Mint links installed executables into `~/.mint/bin`, so you can point the VS Code setting at that path instead of the build output.

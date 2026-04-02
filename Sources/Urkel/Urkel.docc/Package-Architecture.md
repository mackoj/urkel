# Package Architecture

A complete map of Urkel v2's Swift package — modules, dependencies, pipelines, and developer entry points.

## Module dependency graph

Each library target is independently importable. The dependency graph is strictly acyclic and layered by abstraction level.

```mermaid
graph TD
    subgraph ext["External dependencies"]
        SParsing["swift-parsing"]
        SSwiftSyntax["swift-syntax\n(SwiftSyntax · SwiftSyntaxBuilder · SwiftParser)"]
        SMustache["swift-mustache"]
        SDeps["swift-dependencies"]
        SLSP["LanguageServerProtocol\n+ JSONRPC"]
        SAP["swift-argument-parser"]
        SSnap["swift-snapshot-testing"]
    end

    subgraph core["Core library targets"]
        AST["UrkelAST\nPure value-type AST nodes\n(zero external deps)"]
        Parser["UrkelParser\nParser · Printer · Round-trip tests"]
        Validation["UrkelValidation\nSemantic checks"]
        EmitSwift["UrkelEmitterSwift\nSwift typestate codegen\nvia SwiftSyntax"]
        EmitMustache["UrkelEmitterMustache\nMustache template renderer\nswift · kotlin · visualizer.html"]
        Visualize["UrkelVisualize\nGraphJSON builder\nfor vis.js visualizer"]
        Umbrella["Urkel  (umbrella)\nOrchestration · Config\nWatch service · LSP server"]
    end

    subgraph bins["Executables and plugins"]
        CLI["UrkelCLI\ngenerate · watch\nvisualize · paths"]
        LSP["UrkelLSP\nLSP server binary"]
        BTP["UrkelPlugin\nSPM build-tool plugin"]
        CMD["UrkelGenerate\nSPM command plugin"]
    end

    subgraph tests["Test target"]
        Tests["UrkelTests\nUnit · snapshot · property-based"]
    end

    %% external → core
    SParsing    --> Parser
    SSwiftSyntax --> EmitSwift
    SMustache   --> EmitMustache
    SDeps       --> Umbrella
    SLSP        --> Umbrella
    SLSP        --> LSP
    JSONRPC     --> LSP
    SAP         --> CLI
    SSnap       --> Tests

    %% core layering
    AST --> Parser
    AST --> Validation
    AST --> EmitSwift
    AST --> EmitMustache
    AST --> Visualize
    AST --> Umbrella

    Parser      --> Umbrella
    Validation  --> Umbrella
    EmitSwift   --> Umbrella
    EmitMustache --> Umbrella

    %% umbrella → executables
    Umbrella --> CLI
    Umbrella --> LSP
    Visualize --> CLI

    %% CLI → plugins
    CLI --> BTP
    CLI --> CMD

    %% test imports
    Umbrella     --> Tests
    AST          --> Tests
    Parser       --> Tests
    Validation   --> Tests
    EmitSwift    --> Tests
    EmitMustache --> Tests
    Visualize    --> Tests
    CLI          --> Tests
```

## End-to-end generation pipeline

```mermaid
flowchart LR
    file[".urkel file"]

    subgraph pipeline["Urkel Pipeline"]
        direction TB
        P["UrkelParser\nparse + print"]
        A["UrkelAST\nUrkelFile"]
        V["UrkelValidation\nsemantic checks"]
        ES["UrkelEmitterSwift\nSwiftSyntax-based codegen"]
        EM["UrkelEmitterMustache\nMustache template render"]
        VIS["UrkelVisualize\nGraphJSON builder"]
    end

    file --> P
    P    --> A
    A    --> V
    V    -->|valid| ES
    V    -->|valid| EM
    A    --> VIS

    ES  --> swift[".swift\ntypestate interface"]
    EM  --> kotlin[".kt\n(kotlin.mustache)"]
    EM  --> custom["custom output\n(your.mustache)"]

    VIS --> gj["GraphJSON\n(JSON context)"]
    gj  --> EM
    EM  --> html[".html\ninteractive visualizer\n(visualizer.html.mustache)"]
```

The rule is simple:

| Target output | Emitter |
|---|---|
| Swift (compiled typestate code) | `UrkelEmitterSwift` via SwiftSyntax |
| Everything else (Kotlin, HTML, custom) | `UrkelEmitterMustache` via a `.mustache` template |

Adding a new output language only requires dropping a new `.mustache` file into `Sources/UrkelEmitterMustache/Templates/` — no Swift code changes needed.

## Developer entry points

```mermaid
flowchart LR
    Dev["Developer"]

    Dev --> CLI["UrkelCLI\ngenerate · watch\nvisualize · paths"]
    Dev --> BTP["UrkelPlugin\nSPM build-tool plugin\n(DerivedData outputs)"]
    Dev --> CMD["UrkelGenerate\nSPM command plugin\n(writes back to package)"]
    Dev --> LSP["UrkelLSP\nLSP server\n(VS Code extension)"]

    CLI --> GEN["Urkel pipeline"]
    BTP --> GEN
    CMD --> GEN

    GEN --> DD["DerivedData\nbuild-tool plugin output"]
    GEN --> PKG["Package source tree\ncommand plugin · CLI"]

    LSP --> Parser["UrkelParser\ndiagnostics · completion\nhover · formatting · tokens"]
```

- **`UrkelPlugin`** is a build-tool plugin — it writes generated files to the plugin work directory inside DerivedData. Files are recompiled on every build but never checked in.
- **`UrkelGenerate`** is a command plugin — it writes generated files directly into the package source tree. Run once; check the result in to version control.
- **`UrkelCLI`** exposes `generate`, `watch`, `visualize`, and `paths` subcommands for use outside of Xcode or SPM.
- **`UrkelLSP`** is a standalone LSP server binary consumed by the `urkel-vscode-lang` VS Code extension.

## Bundled Mustache templates

| Template file | Triggered by | Output |
|---|---|---|
| `swift.mustache` | `--lang swift` (template mode) | Swift source (alternative to emitter) |
| `kotlin.mustache` | `--lang kotlin` | Kotlin source |
| `visualizer.html.mustache` | `urkel visualize` CLI command | Self-contained HTML+JS visualizer |

## Where to make changes

| Change type | Files to touch |
|---|---|
| Grammar / syntax | `userstories/grammar.ebnf`, `Sources/UrkelParser/UrkelFileParser.swift`, `Tests/UrkelTests/ParserPropertyTests.swift` |
| AST node types | `Sources/UrkelAST/`, `UrkelParser`, `UrkelValidation`, emitters |
| Swift typestate output | `Sources/UrkelEmitterSwift/` |
| Mustache template output | `Sources/UrkelEmitterMustache/Templates/*.mustache` |
| HTML visualizer appearance | `Sources/UrkelEmitterMustache/Templates/visualizer.html.mustache` (no recompile needed) |
| Graph data (nodes/edges) | `Sources/UrkelVisualize/GraphJSON.swift` |
| CLI commands | `Sources/UrkelCLI/UrkelCLI.swift` |
| Semantic validation rules | `Sources/UrkelValidation/` |
| LSP / editor features | `Sources/UrkelLSP/`, `Sources/Urkel/UrkelLanguageServer.swift` |

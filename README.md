# 🤓 Urkel
**"Did I do that?" — Never ask that about your state transitions again.**

Urkel is a lightweight Domain-Specific Language (DSL) and compiler for generating mathematically sound, **compile-time safe** Finite State Machines (FSMs) in Swift. State Machines are defined in a human-readable text format.

By utilizing the **Typestate Design Pattern** and Swift's modern `~Copyable` (noncopyable) and `~Escapable`(nonescapable) types, Urkel ensures that invalid state transitions are entirely unrepresentable in your code. If an event isn't valid for the current state, your app simply will not compile. You will always be able to call the right function at the right time.

---

## 🛑 The Problem: Runtime State Chaos
State management in Swift is notoriously tricky, especially when concurrency gets involved. When you use standard enums and booleans to track state, the compiler has no idea what your domain logic actually is.

**The Car Problem:** If you are building a driving simulator, the compiler will happily let you call `car.accelerate()` even if the car's state is currently `EngineOff` or `StoppedAtRedLight`. 

To prevent this, you end up writing endless `guard` statements, throwing runtime errors, and trying to track down race conditions.

## ✅ The Solution: Typestate & Isolation
Urkel fixes this by shifting state validation to the **compiler level**. 

By encoding the state into the type signature itself, Urkel guarantees linear progression. Furthermore, by leaning heavily on `~Copyable` and strict boundaries, Urkel provides **phenomenal concurrency isolation**. Because states are explicitly consumed and passed forward, you don't have to sprinkle `@Sendable` everywhere to appease the Swift 6 strict concurrency checker.

### 1. Write your `.urkel` definition
Urkel syntax is simple, readable, and relies on a **Bring Your Own Types (BYOT)** philosophy. Here is a real-world example of a File System Watcher:

```text
# FolderWatch.urkel
machine FolderWatch<FolderWatchContext>
@compose Indexer
@factory makeObserver(directory: URL, debounceMs: Int)

@states
  init Idle
  state Running
  final Stopped

@transitions
  # [Current]   -> [Trigger(Payload)]   -> [Next]
  Idle         -> start                  -> Running => Indexer.init
  Running      -> stop                   -> Stopped
```

### 2. Urkel Generates the Typestate Interface
When you build your project, the Urkel SPM Plugin automatically converts that text into a strictly typed, memory-safe Swift interface.

```swift
// ⚡️ GENERATED CODE (Simplified)
public enum Idle {}
public enum Running {}
public enum Stopped {}

extension FolderWatchObserver where State == Idle {
    // You can ONLY call start() when the state is Idle!
    // 'consuming' destroys the Idle state in memory. You cannot call it twice.
    public consuming func start() async -> FolderWatchObserver<Running> { ... }
}

extension FolderWatchObserver where State == Running {
    // start() is physically impossible to call here. 
    public consuming func stop() async -> FolderWatchObserver<Stopped> { ... }
}
```

### 3. You Implement the Business Logic
Urkel generates the *Interface* and the constraints. You provide the *Implementation*. 
Urkel generates a factory client (perfect for Point-Free's `swift-dependencies`). You simply inject the closures that perform your side effects into your isolated context.

```swift
// YOUR CODE
extension FolderWatchClient: DependencyKey {
    public static var liveValue: Self {
        Self(
            makeObserver: { directory, debounceMs in
                return FolderWatchObserver<Idle>(
                    start: { context in
                        await context.startWatching(directory)
                        return context // Pass the isolated context to the next state
                    },
                    stop: { context in
                        await context.cleanup()
                    }
                )
            }
        )
    }
}
```

---

## ✨ Key Features

* **Zero Invalid States:** By encoding states as generic type parameters (`Observer<State>`), illegal transitions result in Xcode build errors, not runtime crashes.
* **Memory Safety & Linear Progression:** Leverages Swift 5.9+ `~Copyable` and `~Escapable` types. When you transition from `A` to `B`, state `A` is `consuming`. You physically cannot accidentally reuse an old state or create duplicated state branches.
* **Painless Swift 6 Concurrency:** By enforcing strict architectural boundaries and state consumption, Urkel isolates side effects perfectly. It makes complex async workflows completely thread-safe without drowning your codebase in `@Sendable` requirements.
* **Bring Your Own Types (BYOT):** Urkel doesn't force you into a proprietary type system. Pass your existing Swift structs, classes, or actors as transition payloads.
* **Magical Tooling:** Includes an SPM `BuildToolPlugin`. Just drop `.urkel` files into your Xcode project, hit `Cmd + B`, and the code generates automatically in the background.

---

## 🤝 Inspiration & Credits

The architectural concepts powering Urkel stand on the shoulders of giants in the Swift community:

* **Typestate Pattern:** The implementation of state-as-types is deeply inspired by Alex Ozun's excellent writings on [Making Illegal States Unrepresentable](https://swiftology.io/articles/making-illegal-states-unrepresentable/) and the [Typestate Pattern in Swift](https://swiftology.io/articles/typestate/).
* **Concurrency & Isolation:** The approach to actor isolation, dependency injection, and safely crossing async boundaries without overusing `Sendable` is heavily inspired by the brilliant folks at [Point-Free](https://www.pointfree.co/) and Matt Massicotte's definitive [Intro to Isolation](https://www.massicotte.org/intro-to-isolation/).

---

## 🚀 Getting Started

### 1. Installation (Swift Package Manager)
Add Urkel to your `Package.swift` dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/mackoj/urkel.git", from: "1.0.0")
]
```
If you want generated files to appear in DerivedData during a normal build, add the build tool plugin to your target:
```swift
.target(
    name: "MyApp",
    plugins: [
        .plugin(name: "UrkelPlugin", package: "urkel")
    ]
)
```
The plugin runs automatically when Xcode or SwiftPM builds the target, so there is no separate “run plugin” button. It resolves the `UrkelCLI` executable tool under the hood and writes generated files into the plugin work directory.

If you want the generated file checked into your package and committed to source control, run the command plugin instead:

```bash
swift package plugin --allow-writing-to-package-directory urkel-generate
```

That command writes directly into the package directory, so it can update a file like `Sources/FolderWatch/FolderWatchClient+Generated.swift`.

Both plugins read the same package-local `urkel-config.json` style files. The only difference is where the generated output lands: the build tool plugin uses DerivedData, while the command plugin can write back into the repository.

### 2. Create your first Machine
Add a file named `Machine.urkel` anywhere in your target's source folder. The plugin will automatically detect it, compile it, and make the Typestate boilerplate available to your Swift code immediately.

### 2.1 Configure the plugin (Optional)
If you want to change where generated files go or export to another language/template, add a `.urkel-config.json` file next to your `.urkel` source files or any parent directory:

```json
{
  "swiftImports": ["Foundation", "Dependencies"],
  "outputFile": "ConfiguredFolderWatch.swift",
  "template": "Templates/machine.mustache",
  "outputExtension": "kt",
  "sourceExtensions": ["urkel"]
}
```

Supported keys:

* `outputFile`: output path relative to the current generator root. In build-tool mode that root is the plugin work directory; in command-plugin mode it is the package directory.
* `template`: path to a custom Mustache template, resolved relative to the config file.
* `language`: bundled language template name, currently `kotlin`.
* `swiftImports`: optional import list used by the native Swift emitter.
* `templateImports`: optional import list used by template/language emitters.
* `outputExtension`: overrides the generated file extension.
* `sourceExtensions`: source file extensions the plugin should process, defaulting to `["urkel"]`.

### 3. CLI Usage (Optional)
If you prefer manual generation or want to watch a directory during development outside of Xcode:
```bash
# Generate Swift files once
swift run UrkelCLI generate ./Sources --output ./Generated

# Watch a directory and regenerate live on file save
swift run UrkelCLI watch ./Sources --output ./Generated
```

### 4. Generation Architecture (for contributors)

Urkel parses `.urkel` files once into `MachineAST`, then emits code through one of two paths:

* `SwiftCodeEmitter` for native Swift generation
* `TemplateCodeEmitter` for template-based generation (`--template` and `--lang kotlin`)

Kotlin currently uses the template emitter with the bundled `kotlin.mustache` template.

For deeper internals (CLI/plugins/watch/LSP, module map, and diagrams), see:

* `Sources/Urkel/Urkel.docc/Codebase-Architecture.md`

### 5. User Stories and Roadmap

Urkel implementation decisions and roadmap are tracked as user stories in:

* `User Stories/README.md`

Stories are grouped by epic and include objective, acceptance criteria, implementation notes, and test strategy.

### 6. Grammar Reference

The formal language grammar is versioned at repository root:

* `grammar.ebnf`

For narrative documentation of the same grammar and language rules, see:

* `Sources/Urkel/Urkel.docc/Language-Spec.md`

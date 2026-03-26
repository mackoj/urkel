# US-13.1: Wire the UrkelPlugin and per-machine configs into the MFSM example

**Epic:** 13 — Example Quality  
**Status:** Proposed

---

## 1. Objective

Make the `Examples/MFSM` package a fully self-contained, regenerable example by
wiring the `UrkelPlugin` build-tool plugin and providing one `urkel-config.json`
per `.urkel` source file so the generator knows exactly where to write each
machine's three output files.

---

## 2. Current State

`Package.swift` declares no plugin at all — the generated Swift files
(`MainFSMMachine.swift`, `SomeFeature1Machine.swift`, etc.) are currently
checked-in manually with no way to regenerate them through the standard Urkel
workflow.  There are no `urkel-config.json` files anywhere in the package.

---

## 3. What Must Be Done

### 3.1 Add `UrkelPlugin` to `Package.swift`

Add the `UrkelPlugin` build-tool plugin to the `MultipleFSM` target so the three
`.urkel` files are picked up automatically on every build:

```swift
.target(
    name: "MultipleFSM",
    dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
    ],
    plugins: [
        .plugin(name: "UrkelPlugin", package: "urkel")
    ]
)
```

### 3.2 Create one `urkel-config.json` per machine subfolder

The plugin walks **upward** from each `.urkel` source file looking for a config.
Because each machine lives in its own subdirectory under `Urkels/`, placing a
config in that same directory gives per-machine output routing.

| Config location | `outputFolder` | Machine |
|---|---|---|
| `Sources/MultipleFSM/Urkels/MFSM/urkel-config.json` | `Sources/MultipleFSM/Urkels/MFSM` | `MainFSM` |
| `Sources/MultipleFSM/Urkels/SomeFeature1/urkel-config.json` | `Sources/MultipleFSM/Urkels/SomeFeature1` | `SomeFeature1` |
| `Sources/MultipleFSM/Urkels/SomeFeature2/urkel-config.json` | `Sources/MultipleFSM/Urkels/SomeFeature2` | `SomeFeature2` |

Each config also declares the Swift imports needed by the generated files:

```json
{
  "outputFolder": "Sources/MultipleFSM/Urkels/<MachineName>",
  "imports": {
    "swift": ["Foundation", "Dependencies"]
  }
}
```

---

## 4. Acceptance Criteria

- **Given** the updated `Package.swift` and three config files are in place.
- **When** `swift package plugin --allow-writing-to-package-directory urkel-generate` is run from `Examples/MFSM`.
- **Then** the three machine files for each `.urkel` source are (re)written into the correct `Urkels/<MachineName>/` subdirectory.
- **And** `swift build` of the `MultipleFSM` target succeeds without manual file edits.

---

## 5. Out of Scope

- Changes to any `.urkel` source files or generated Swift files.
- Changes to the Urkel core library or plugin logic.

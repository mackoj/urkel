# UrkelBird

A small Flappy Bird-like FSM example built with Urkel.

## What this example demonstrates

- machine definition in `Sources/UrkelBird/urkelbird.urkel`
- generated typestate API in `Sources/UrkelBird/urkelbird+Generated.swift`
- domain sidecar behavior in `Sources/UrkelBird/UrkelBird.swift`
- keyboard-playable SpriteKit demo app in `Sources/UrkelBirdDemo/main.swift`
- Swift Testing coverage in `Tests/UrkelBirdTests/UrkelBirdTests.swift`

The generated file stays generic (states, transitions, dependency client), while game rules stay in sidecar code you own.

## SpriteKit and GameplayKit

This demo uses **SpriteKit** directly for rendering and keyboard input.

For this scope, **GameplayKit is optional** and not required:

- SpriteKit already gives everything needed for a small loop (scene, updates, input, nodes)
- Urkel already models the gameplay lifecycle and transitions

Use GameplayKit later if you want reusable component/entity systems, behavior trees, or pathfinding.

## State machine

UrkelBird models:

- `Ready` (initial)
- `Playing`
- `Crashed` (final)

Transitions:

- `Ready -> flap -> Playing`
- `Playing -> flap -> Playing`
- `Playing -> tick(deltaY: Int) -> Playing`
- `Playing -> scorePipe -> Playing`
- `Playing -> collide(reason: String) -> Crashed`

## Regenerate after changing the machine

From this directory:

```bash
swift package plugin --allow-writing-to-package-directory urkel-generate
```

Or directly with CLI:

```bash
cd /Users/mac-JMACKO01/Developer/urkel
swift run UrkelCLI generate \
  ./Examples/UrkelBird/Sources/UrkelBird/urkelbird.urkel \
  --output ./Examples/UrkelBird/Sources/UrkelBird \
  --output-file urkelbird+Generated.swift
```

## Run tests

```bash
swift test --quiet
```

## Run the playable demo

```bash
swift run UrkelBirdDemo
```

Controls:

- `Space`: flap
- `R`: restart after crash

The HUD displays score, altitude, and tick count, and crash reason when the machine enters `Crashed`.

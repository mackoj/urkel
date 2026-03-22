# BluetoohBlender

A richer developer-facing Urkel example showing:

- Bluetooth lifecycle states (`Disconnected`, `Scanning`, `Connecting`, `Connected*`, `Error`, `TurnedOff`)
- Bowl-presence constraints (`ConnectedWithBowl`, `ConnectedWithoutBowl`)
- Blending lifecycle/speeds (`BlendSlow`, `BlendMedium`, `BlendHigh`, `Paused`)

## What this demonstrates

- Generated typestate API from `bluetoohblender.urkel`
- Domain runtime wiring in `BluetoohBlender.swift`
- Swift Testing coverage for realistic transitions

## Regenerate after editing machine

This example uses config-driven emitter imports in `urkel-config.json` (`swiftImports`), so the `.urkel` stays emitter-agnostic.

```bash
cd /Users/mac-JMACKO01/Developer/urkel
swift run UrkelCLI generate \
  Examples/BluetoohBlender/Sources/BluetoohBlender/bluetoohblender.urkel \
  --output Examples/BluetoohBlender/Sources/BluetoohBlender
```

## Run tests

```bash
cd /Users/mac-JMACKO01/Developer/urkel/Examples/BluetoohBlender
swift test --quiet
```

## Notes on bowl + blending rules

- You can remove/add bowl only while connected.
- Starting blend requires `ConnectedWithBowl`.
- If bowl is absent, blend transitions are blocked by typestate wrapper behavior.
- Blending can change speed, pause/resume, and stop back to connected-with-bowl.
- Bluetooth lifecycle includes scan start/stop, connect cancel, connect fail, and power off (`switchOff`).

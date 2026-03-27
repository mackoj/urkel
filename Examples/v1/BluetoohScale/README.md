# BluetoohScale

A composed Urkel example with two machines:

- `BLE.urkel`: radio lifecycle, first connection, reconnection, and sync transport
- `scale.urkel`: scale measurement lifecycle that composes BLE via `@compose BLE`

## What this demonstrates

- Multi-machine composition (`Scale` + `BLE`)
- Forking from a scale transition into BLE state creation (`=> BLE.init`)
- Sidecar runtime wiring in Swift for both machines
- Example tests for scale flow, BLE reconnect flow, and orchestrator spawn behavior

## Regenerate generated files

This package keeps generated files checked in for easy reading and customization.

```bash
cd /Users/mac-JMACKO01/Developer/urkel
swift run UrkelCLI generate \
  Examples/BluetoohScale/Sources/BluetoohScale/BLE.urkel \
  --output Examples/BluetoohScale/Sources/BluetoohScale \
  --output-file BLEFSMClient.swift

swift run UrkelCLI generate \
  Examples/BluetoohScale/Sources/BluetoohScale/scale.urkel \
  --output Examples/BluetoohScale/Sources/BluetoohScale \
  --output-file ScaleFSMClient.swift
```

## Run tests

```bash
cd /Users/mac-JMACKO01/Developer/urkel/Examples/BluetoohScale
swift test --quiet
```

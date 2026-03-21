# BluetoohBlender

A minimal, developer-facing example showing how to use Urkel-generated Swift code for a Bluetooth-like finite state machine.

## What this example demonstrates

- Generated typestate API from `bluetoohblender.urkel` in `Sources/BluetoohBlender/bluetoohblender+Generated.swift`
- Domain sidecar runtime wiring in `Sources/BluetoohBlender/BluetoohBlender.swift`
- Swift Testing coverage in `Tests/BluetoohBlenderTests/BluetoohBlenderTests.swift`

The goal is to keep generated code stable and generic, while keeping platform/domain behavior in sidecar code you own.

## Generated vs sidecar responsibilities

Urkel-generated code provides:

- machine state markers (`Disconnected`, `Scanning`, `Connecting`, `Connected`, `Error`)
- typed transitions (`startScan`, `deviceFound`, `timeout`, `connectSuccess`, `connectFail`, `disconnect`)
- dependency client and `DependencyValues` integration
- runtime builder (`BluetoohBlenderClientRuntime` + `BluetoohBlenderClient.fromRuntime`)

Sidecar code (`BluetoohBlender.swift`) provides:

- domain callbacks (`BluetoohBlenderRuntimeHandlers`)
- adaptation from domain callbacks to generated runtime transitions (`BluetoohBlenderClient.runtime`)
- convenience configuration (`.noop`)

## Regenerate after editing the machine

When you change `bluetoohblender.urkel`, regenerate the checked-in Swift source:

```bash
swift package --package-path ../../ plugin \
  --allow-writing-to-package-directory urkel-generate \
  --package-path /Users/mac-JMACKO01/Developer/urkel/Examples/BluetoohBlender
```

Or from this directory:

```bash
swift package plugin --allow-writing-to-package-directory urkel-generate
```

## Run tests

```bash
swift test --quiet
```

## Typical app integration shape

In your app target, build a real runtime by mapping Bluetooth APIs/delegate events into handlers:

```swift
let client = BluetoohBlenderClient.runtime(
  handlers: .init(
    startScan: { /* centralManager.scanForPeripherals */ },
    deviceFound: { peripheral in /* track selected peripheral */ },
    timeout: { /* cancel scan */ },
    connectSuccess: { /* update connection state */ },
    connectFail: { error in /* map/log error */ },
    disconnect: { /* clean up */ }
  )
)
```

That keeps platform behavior local while preserving type-safe state transitions from generated code.

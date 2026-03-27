# SmartWatch Example

A three-machine Urkel example modelling an iOS companion app that connects to a BLE smartwatch.

This example illustrates:
- **Composed machines** — `HeartRate` embeds `BLE` via `@compose`
- **Context threading** — `WatchBLEContext` tracks retry count and connected device; `HeartRateContext` accumulates readings
- **Standalone context-threaded machine** — `WatchAudio` uses the auto-generated runtime context
- **A real coordinator pattern** — `WatchCoordinator` drives both machines and a CoreBluetooth bridge through a complete measurement session

## Machines

### `BLE.urkel` → `BLEClient`

Manages the CoreBluetooth connection lifecycle to the watch peripheral.

```
Off → Scanning → Connecting → Connected → Disconnected (final)
                                    ↕ Reconnecting ↕ Error
```

Key transitions: `startScan`, `watchDiscovered(device:)`, `connectionEstablished`, `retry`, `powerDown`

### `HeartRate.urkel` → `HeartRateClient`

Drives the optical heart-rate sensor. Composes `BLE` so both machines move together.
The `activate` transition uses the FORK operator (`=> BLE.init`) to spawn the BLE machine.

```
Off → Activating → Idle → Measuring → Idle (loop) → Terminated (final)
                               ↕ SensorLost ↕ Error
```

Key transitions: `activate` (FORK), `sensorReady`, `startMeasurement`, `measurementComplete(bpm:)`, `deactivate`

Forwarded BLE transitions on `HeartRateState`: `bleStartScan()`, `bleWatchDiscovered(device:)`, `bleConnectionEstablished()`, `blePowerDown()`

### `Audio.urkel` → `WatchAudioClient`

Controls audio playback on the watch (AVFoundation-backed). Independent from the BLE stack.

```
Off → Initializing → Idle → Playing → Idle
                               ↕ Paused
```

Notable: `adjustVolume(level:)` is a self-referencing transition (`Playing → Playing`) — volume changes without leaving the playing state.

## Architecture

```
WatchCoordinator (actor)
    ├── WatchBLEBridge (CoreBluetooth delegate ↔ async/await)
    ├── BLEClient.makeLive(bridge:)
    │       └── BLEMachine<State>  ─────────────┐
    └── HeartRateClient.makeLive(bridge:)        │
            └── HeartRateMachine<State>          │
                    └── BLEState ────────────────┘ (composed)
```

## Usage

```swift
let coordinator = WatchCoordinator()
let readings = try await coordinator.measureHeartRate(samples: 5)
// → [HeartRateReading(bpm: 72), HeartRateReading(bpm: 74), ...]
```

## Testing

```swift
// Inject a noop system — no real hardware, no network
@Dependency(\.bLE) var bleClient
// bleClient.liveValue → real CoreBluetooth
// bleClient.testValue → fatalError (forces explicit configuration in tests)

let system = SmartWatchSystem.noop
var state = system.makeHeartRateState()
state = try await state.activate()           // HeartRateStateOff → Activating
state = try await state.bleStartScan()       // BLE: Off → Scanning
state = try await state.bleWatchDiscovered(device: .init(name: "Test Watch"))
state = try await state.bleConnectionEstablished()  // BLE: Connecting → Connected
state = try await state.sensorReady()        // HeartRate: Activating → Idle
state = try await state.startMeasurement()   // Idle → Measuring
state = try await state.measurementComplete(bpm: 72)  // Measuring → Idle
state = try await state.deactivate()         // Idle → Terminated
state = try await state.blePowerDown()       // BLE: Connected → Disconnected
_ = consume state  // ✅ compiler enforces this is actually consumed
```

Notice: the compiler prevents calling `startMeasurement()` while in `Activating`, or `measurementComplete(bpm:)` while in `Idle`. Wrong-state calls are **compile-time errors**.

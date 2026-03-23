# Composing Multiple Machines

Learn how to build complex systems by combining multiple Urkel state machines.

## Overview

As your application grows, you'll often need to manage multiple related state machines. Urkel provides the `@compose` declaration to reference sub-machines and coordinate their transitions.

This article covers:
- How `@compose` declarations work
- Passing composed machines as factory parameters
- Real-world examples (BLE scanning with multiple state machines)
- Current limitations and the roadmap for full orchestration
- Patterns for managing sub-FSM lifecycles

## Basic Composition with @compose

The `@compose` declaration tells Urkel that your machine references another machine:

```text
machine BluetoothScanner<ScannerContext>
@compose CentralManager
@compose Peripheral
@factory makeBLEScanner()

@states
  init Idle
  state Scanning
  final Stopped

@transitions
  Idle -> startScan -> Scanning => CentralManager.init, Peripheral.init
  Scanning -> stopScan -> Stopped
```

When you declare `@compose CentralManager`, you're saying: "This machine will coordinate with a CentralManager FSM."

The generated code creates a dependency relationship:

```swift
// Generated
public struct BluetoothScannerClient {
    let makeObserver: (@escaping @Sendable () -> CentralManager<Idle>,
                       @escaping @Sendable () -> Peripheral<Idle>) -> BluetoothScanner<Idle>
}

// Your implementation
let client = BluetoothScannerClient(
    makeObserver: { centralManagerFactory, peripheralFactory in
        let centralManager = centralManagerFactory()
        let peripheral = peripheralFactory()
        
        return BluetoothScanner<Idle>(
            startScan: {
                let scanningCentral = await centralManager.startScan()
                let scanningPeripheral = await peripheral.initialize()
                return BluetoothScanner<Scanning>(...)
            }
        )
    }
)
```

---

## Real-World Example: Bluetooth Scanning

Here's a realistic example of composing BLE machines:

### Define the Sub-Machines

**CentralManager.urkel** — Manages the BLE central (scanner):
```text
machine CentralManager
@factory initCentral()

@states
  init Idle
  state Scanning
  final Stopped

@transitions
  Idle -> start -> Scanning
  Scanning -> stop -> Stopped
  Scanning -> didFindPeripheral(peripheral: Peripheral) -> Scanning
```

**Peripheral.urkel** — Manages discovered peripherals:
```text
machine Peripheral
@factory initPeripheral(uuid: UUID)

@states
  init Discovered
  state Connected
  state BondingInProgress
  final Bonded

@transitions
  Discovered -> connect -> Connected
  Connected -> startBonding -> BondingInProgress
  BondingInProgress -> bonded -> Bonded
```

### Define the Parent Machine

**BluetoothScanner.urkel** — Orchestrates both:
```text
machine BluetoothScanner<ScannerContext>
@compose CentralManager
@compose Peripheral
@factory makeScanner()

@states
  init Idle
  state Scanning
  final Stopped

@transitions
  Idle -> startScan -> Scanning => CentralManager.init, Peripheral.init
  Scanning -> stopScan -> Stopped
```

### Implement the Client

```swift
extension BluetoothScannerClient: DependencyKey {
    public static var liveValue: Self {
        BluetoothScannerClient(
            makeObserver: { makeCentral, makePeripheral in
                return BluetoothScanner<Idle>(
                    startScan: {
                        let central = makeCentral()
                        let peripheral = makePeripheral()
                        
                        let scanning = await central.start()
                        let initialized = await peripheral.connect()
                        
                        return BluetoothScanner<Scanning>(
                            context: ScannerContext(
                                central: scanning,
                                peripheral: initialized
                            )
                        )
                    },
                    stopScan: { context in
                        let stopped = await context.central.stop()
                        // Clean up peripheral if needed
                        return BluetoothScanner<Stopped>(...)
                    }
                )
            }
        )
    }
}
```

---

## Current Limitations

Urkel's composition system works for **passing-through** sub-machines, but orchestration is limited.

### What Works

✅ Reference multiple composed machines in your `.urkel` file
✅ Initialize composed machines during a transition
✅ Pass composed machines as factory parameters
✅ Access composed machine state through your context

### What Doesn't Work Yet

❌ No built-in way to manage the lifecycle of sub-machines
❌ No operator to fork/spawn new sub-FSM instances dynamically
❌ Sub-machines are provided by factories; you can't dynamically create them in transitions
❌ No "orchestrator" pattern for managing parent-child FSM relationships

### Example of Current Limitation

```swift
// ❌ This pattern isn't fully supported yet:
Scanning -> didFindPeripheral(uuid: UUID) -> Scanning => Peripheral.init

// Why: You'd need to create a new Peripheral FSM for each discovered device
// But Urkel's current @compose assumes machines are initialized once in a factory
```

---

## Workaround: Factory Closures as Dependencies

Until the fork operator is available (Epic 11), use the Dependencies library to pass factory closures:

```swift
import Dependencies

public struct ScannerContext {
    let makePeripheralFactory: @Sendable (UUID) -> Peripheral<Idle>
}

extension BluetoothScanner {
    public consuming func didFindPeripheral(uuid: UUID) async -> BluetoothScanner<Scanning> {
        let context = self.context
        let newPeripheral = context.makePeripheralFactory(uuid)
        
        // Add to collection of peripherals
        var updatedPeripherals = context.peripherals
        updatedPeripherals[uuid] = newPeripheral
        
        return BluetoothScanner<Scanning>(
            context: ScannerContext(
                peripherals: updatedPeripherals,
                makePeripheralFactory: context.makePeripheralFactory
            )
        )
    }
}
```

This pattern allows you to create sub-FSMs on demand while maintaining type safety.

---

## Best Practices for Composition

### 1. Keep Sub-Machines Independent

Each composed machine should be independently testable:

```swift
// Test CentralManager in isolation
func testCentralManagerScanning() {
    let central = CentralManager<Idle>()
    let scanning = await central.start()
    assert(/* scanning state is valid */)
}

// Test Peripheral independently
func testPeripheralBonding() {
    let peripheral = Peripheral<Discovered>(uuid: testUUID)
    let connected = await peripheral.connect()
    let bonding = await connected.startBonding()
    assert(/* bonding state is valid */)
}
```

### 2. Manage Sub-Machine Collections with IdentifiedArray

When managing multiple instances of the same sub-machine (e.g., multiple Peripherals), use IdentifiedArray:

```swift
import IdentifiedCollections

public struct ScannerContext {
    var peripherals: IdentifiedArrayOf<PeripheralState> = []
    
    mutating func addPeripheral(uuid: UUID) {
        let peripheral = Peripheral<Discovered>(uuid: uuid)
        peripherals.append(PeripheralState(id: uuid, machine: peripheral))
    }
}
```

### 3. Use State Containers for Complex Context

When your context grows, use nested state structs:

```swift
public struct ScannerContext {
    public let central: CentralManager<Scanning>
    public let peripherals: IdentifiedArrayOf<PeripheralState>
    public let config: ScanConfiguration
    
    mutating func update(_ keyPath: WritableKeyPath<Self, SomeType>, to value: SomeType) {
        self[keyPath: keyPath] = value
    }
}

public struct PeripheralState: Identifiable {
    let id: UUID
    var machine: Peripheral<DiscoveredState>
}
```

### 4. Keep Factories Simple

Pass only the minimum data needed to initialize sub-machines:

```swift
// ✅ Simple
let makePeripheral = { (uuid: UUID) -> Peripheral<Idle> in
    Peripheral<Idle>(uuid: uuid)
}

// ❌ Complex (too much context)
let makePeripheral = { (uuid: UUID, central: CentralManager<Scanning>, delegate: SomeDelegate) in
    // ...
}
```

---

## Roadmap: Epic 11 (Orchestration)

Full support for complex composition is coming in Epic 11 — Orchestration.

**Planned features:**

1. **Fork Operator** — Create new sub-FSM instances dynamically:
   ```text
   Scanning -> didFindPeripheral(uuid: UUID) -> Scanning => Peripheral.fork(uuid)
   ```

2. **Lifecycle Management** — Automatic handling of sub-FSM creation and cleanup:
   ```swift
   let scanner = BluetoothScanner<Idle>(...)
   let scanning = await scanner.startScan()
   // Automatically manages Peripheral instances
   ```

3. **Orchestrator Actor** — Manage parent-child FSM relationships:
   ```swift
   let orchestrator = ScannerOrchestrator(scanner)
   await orchestrator.addPeripheral(uuid)
   ```

4. **Sub-FSM Events** — React to events from child machines:
   ```text
   Scanning -> didConnectPeripheral(peripheral: Peripheral<Connected>) -> Scanning
   ```

**Timeline:** TBD. Epic 11 is under active development.

---

## Testing Composed Machines

### Unit Test Individual Machines

Each composed machine should be independently testable:

```swift
func testCentralManagerTransitions() {
    let central = CentralManager<Idle>()
    
    let scanning = await central.start()
    
    // Assert state is correct
    assert(scanning is CentralManager<Scanning>)
}
```

### Integration Test Composition

Test the parent machine with mock factories:

```swift
@Test
func testBluetoothScannerWithMocks() async throws {
    let mockCentral = CentralManager<Idle>()
    let mockPeripheral = Peripheral<Discovered>(uuid: testUUID)
    
    let makeCentral = { mockCentral }
    let makePeripheral = { mockPeripheral }
    
    let scanner = BluetoothScanner<Idle>(
        makeObserver: { _, _ in
            BluetoothScanner<Idle>(...)
        }
    )
    
    let scanning = await scanner.startScan()
    // Assert the combined state is valid
}
```

### Use Dependency Injection

Leverage the Dependencies library to inject composed machines:

```swift
public struct BluetoothScannerClient {
    @Dependency(\.centralManager) var makeCentral
    @Dependency(\.peripheralFactory) var makePeripheral
    
    // Use in your implementation
}
```

---

## Common Patterns

### Pattern 1: Parent Controls Child Lifecycle

The parent machine fully controls when child machines are created and destroyed:

```swift
Idle -> startScan -> Scanning => CentralManager.init
Scanning -> stopScan -> Stopped  // CentralManager cleaned up
```

**When to use:** Simple hierarchies where the parent fully owns the child.

### Pattern 2: Multiple Children of Same Type

Manage multiple instances of the same sub-machine:

```swift
public struct ScannerContext {
    var peripherals: IdentifiedArrayOf<Peripheral<DiscoveredState>> = []
}

// In a transition:
peripherals.append(Peripheral<Discovered>(uuid: newUUID))
```

**When to use:** Collections of related state machines (e.g., multiple connected devices).

### Pattern 3: Child Events Affect Parent

Child machines emit events; the parent reacts:

```text
machine Peripheral
@transitions
  Connected -> didDisconnect -> Discovered

machine BluetoothScanner
@transitions
  Scanning -> peripheral.didDisconnect(peripheral) -> Scanning
```

**When to use:** When child state changes require parent coordination.

---

## Debugging Composition

### Print State in Composition

Add debug logging to understand the composition flow:

```swift
let scanning = await scanner.startScan()

// Log the state
print("Scanner is in state: \(type(of: scanning))")
print("Central manager is in state: \(type(of: scanning.context.central))")
print("Peripherals: \(scanning.context.peripherals.count)")
```

### Test State Consistency

Write tests that verify all sub-machines are in consistent states:

```swift
@Test
func testComposedStateConsistency() async {
    let scanner = /* ... */
    let scanning = await scanner.startScan()
    
    // Assert parent and children are in compatible states
    #expect(type(of: scanning) == BluetoothScanner<Scanning>.self)
    #expect(scanning.context.central is CentralManager<Scanning>)
}
```

### Use Custom Debug Descriptions

Implement CustomStringConvertible for your context types:

```swift
extension ScannerContext: CustomStringConvertible {
    var description: String {
        "ScannerContext(peripherals: \(peripherals.count), status: \(central))"
    }
}
```

---

## Summary

Composition in Urkel allows you to:

✅ Reference multiple sub-machines in your FSM
✅ Initialize composed machines during transitions
✅ Pass composed machines as factory parameters
✅ Manage sub-machine collections with IdentifiedArray
✅ Test each machine independently

Current limitations are by design—full orchestration (Epic 11) will expand these capabilities.

For now, use **factory closures and dependency injection** to manage complex multi-machine scenarios. This pattern is testable, type-safe, and aligns with Swift best practices.

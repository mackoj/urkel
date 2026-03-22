import CoreBluetooth
import Foundation

// MARK: - BLE Errors

public enum BLEError: Error, LocalizedError, Sendable {
    case radioPoweredOff
    case scanTimedOut
    case connectionFailed(String)
    case noWriteCharacteristic
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .radioPoweredOff:        return "Bluetooth radio is powered off."
        case .scanTimedOut:           return "BLE scan timed out without finding a device."
        case .connectionFailed(let r): return "BLE connection failed: \(r)"
        case .noWriteCharacteristic:  return "No writable BLE characteristic found."
        case .writeFailed(let r):     return "BLE write failed: \(r)"
        }
    }
}

// MARK: - BLE Bridge

/// Bridges CoreBluetooth's delegate callbacks into `async`/`await` continuations.
public final class BLEBridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {
    private var central: CBCentralManager!
    private(set) var connectedPeripheral: CBPeripheral?
    private var syncCharacteristic: CBCharacteristic?

    private var powerOnContinuation: CheckedContinuation<Void, Error>?
    private var discoveryContinuation: CheckedContinuation<BLEDevice, Error>?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var writeContinuation: CheckedContinuation<Void, Error>?

    public override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Async API

    /// Suspends until the CoreBluetooth radio reaches `.poweredOn`.
    public func waitForPoweredOn() async throws {
        try await withCheckedThrowingContinuation { cont in
            switch central.state {
            case .poweredOn: cont.resume()
            case .poweredOff, .unauthorized, .unsupported:
                cont.resume(throwing: BLEError.radioPoweredOff)
            default:
                powerOnContinuation = cont
            }
        }
    }

    /// Starts a BLE peripheral scan.
    public func startScanning(serviceUUIDs: [CBUUID]? = nil) {
        central.scanForPeripherals(withServices: serviceUUIDs, options: nil)
    }

    /// Suspends until a peripheral is discovered or the scan times out.
    public func waitForDevice(timeout: TimeInterval = 15) async throws -> BLEDevice {
        try await withCheckedThrowingContinuation { cont in
            discoveryContinuation = cont
            Task {
                try await Task.sleep(for: .seconds(timeout))
                if self.discoveryContinuation != nil {
                    self.central.stopScan()
                    self.discoveryContinuation?.resume(throwing: BLEError.scanTimedOut)
                    self.discoveryContinuation = nil
                }
            }
        }
    }

    /// Connects to a discovered peripheral and waits until services/characteristics are ready.
    public func connect(to device: BLEDevice) async throws {
        guard let p = connectedPeripheral, p.identifier == device.identifier else {
            throw BLEError.connectionFailed("Peripheral \(device.identifier) not found in cache.")
        }
        try await withCheckedThrowingContinuation { cont in
            connectContinuation = cont
            central.connect(p, options: nil)
        }
    }

    /// Writes an encoded `ScalePayload` to the sync characteristic and waits for acknowledgement.
    public func write(payload: ScalePayload) async throws {
        guard let char = syncCharacteristic, let p = connectedPeripheral else {
            throw BLEError.noWriteCharacteristic
        }
        let data = try JSONEncoder().encode(payload)
        try await withCheckedThrowingContinuation { cont in
            writeContinuation = cont
            p.writeValue(data, for: char, type: .withResponse)
        }
    }

    /// Disconnects the active peripheral.
    public func disconnect() {
        if let p = connectedPeripheral { central.cancelPeripheralConnection(p) }
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            powerOnContinuation?.resume()
            powerOnContinuation = nil
        case .poweredOff, .unauthorized, .unsupported:
            powerOnContinuation?.resume(throwing: BLEError.radioPoweredOff)
            powerOnContinuation = nil
        default: break
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        central.stopScan()
        connectedPeripheral = peripheral
        let device = BLEDevice(identifier: peripheral.identifier, name: peripheral.name ?? "Unknown")
        discoveryContinuation?.resume(returning: device)
        discoveryContinuation = nil
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectContinuation?.resume(throwing: BLEError.connectionFailed(error?.localizedDescription ?? "Unknown"))
        connectContinuation = nil
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            connectContinuation?.resume(throwing: BLEError.connectionFailed(error.localizedDescription))
            connectContinuation = nil
            return
        }
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        if let char = service.characteristics?.first(where: { $0.properties.contains(.write) }) {
            syncCharacteristic = char
            connectContinuation?.resume()
            connectContinuation = nil
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            writeContinuation?.resume(throwing: BLEError.writeFailed(error.localizedDescription))
        } else {
            writeContinuation?.resume()
        }
        writeContinuation = nil
    }
}

// MARK: - BLEClient Live

public extension BLEClient {
    /// Creates the live CoreBluetooth implementation using a shared bridge.
    /// Pass the same `bridge` to `ScaleCoordinator` to allow coordinating discovery.
    static func makeLive(bridge: BLEBridge = BLEBridge()) -> Self {
        .fromRuntime(.init(
            initialContext: { .init() },
            powerOnTransition: { ctx in
                // Suspends until the CoreBluetooth radio is ready.
                try await bridge.waitForPoweredOn()
                return ctx
            },
            radioReadyTransition: { ctx in
                // Kicks off a peripheral scan; the coordinator awaits bridge.waitForDevice().
                bridge.startScanning()
                return ctx
            },
            deviceDiscoveredDeviceBLEDeviceTransition: { ctx, device in
                // Connects to the discovered device and waits for characteristics.
                try await bridge.connect(to: device)
                var c = ctx; c.lastSeenDevice = device; return c
            },
            scanTimeoutTransition: { ctx in ctx },
            connectionEstablishedTransition: { ctx in ctx },
            connectionFailedReasonStringTransition: { ctx, _ in ctx },
            retryTransition: { ctx in ctx },
            retriesExhaustedTransition: { ctx in ctx },
            startSyncPayloadScalePayloadTransition: { ctx, payload in
                // Writes the payload over BLE and waits for write acknowledgement.
                try await bridge.write(payload: payload)
                return ctx
            },
            syncSucceededTransition: { ctx in ctx },
            syncFailedReasonStringTransition: { ctx, _ in ctx },
            peripheralDisconnectedTransition: { ctx in ctx },
            resetRadioTransition: { ctx in ctx },
            powerDownTransition: { ctx in
                bridge.disconnect()
                return ctx
            }
        ))
    }
}

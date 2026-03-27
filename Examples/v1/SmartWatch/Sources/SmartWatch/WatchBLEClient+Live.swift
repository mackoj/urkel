import CoreBluetooth
import Foundation

// MARK: - BLE Errors

public enum WatchBLEError: Error, LocalizedError, Sendable {
    case radioPoweredOff
    case scanTimedOut
    case connectionFailed(String)
    case missingHRService
    case missingHRCharacteristic

    public var errorDescription: String? {
        switch self {
        case .radioPoweredOff:
            return "Bluetooth radio is powered off."
        case .scanTimedOut:
            return "BLE scan timed out without finding a watch peripheral."
        case .connectionFailed(let r):
            return "BLE connection failed: \(r)"
        case .missingHRService:
            return "Heart Rate Service (0x180D) not found on connected peripheral."
        case .missingHRCharacteristic:
            return "Heart Rate Measurement characteristic (0x2A37) not found."
        }
    }
}

// MARK: - WatchBLE Bridge

/// Bridges CoreBluetooth's delegate callbacks into `async`/`await` continuations and
/// buffers heart-rate notifications so `readHeartRate()` can suspend until the next sample.
///
/// Share one bridge instance between `BLEClient.makeLive(bridge:)` and `WatchCoordinator`
/// so both can coordinate on the same physical peripheral.
public final class WatchBLEBridge: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, @unchecked Sendable {

    // Standard GATT UUIDs for the Heart Rate profile.
    nonisolated(unsafe) private static let heartRateServiceUUID     = CBUUID(string: "180D")
    nonisolated(unsafe) private static let heartRateMeasurementUUID = CBUUID(string: "2A37")

    private var central: CBCentralManager!
    private(set) var connectedPeripheral: CBPeripheral?
    private var hrCharacteristic: CBCharacteristic?

    private var powerOnContinuation:   CheckedContinuation<Void, Error>?
    private var discoveryContinuation: CheckedContinuation<BLEDevice, Error>?
    private var connectContinuation:   CheckedContinuation<Void, Error>?
    private var hrContinuation:        CheckedContinuation<Int, Error>?

    /// All readings collected during the current session (appended on each HR notification).
    public private(set) var collectedReadings: [HeartRateReading] = []

    public override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Async API

    /// Suspends until `CBCentralManager` reaches `.poweredOn`.
    public func waitForPoweredOn() async throws {
        try await withCheckedThrowingContinuation { cont in
            switch central.state {
            case .poweredOn:
                cont.resume()
            case .poweredOff, .unauthorized, .unsupported:
                cont.resume(throwing: WatchBLEError.radioPoweredOff)
            default:
                powerOnContinuation = cont
            }
        }
    }

    /// Starts scanning for a watch advertising the Heart Rate service.
    public func startScanning() {
        central.scanForPeripherals(
            withServices: [WatchBLEBridge.heartRateServiceUUID],
            options: nil
        )
    }

    /// Suspends until a watch peripheral is discovered or the scan times out.
    public func waitForWatch(timeout: TimeInterval = 15) async throws -> BLEDevice {
        try await withCheckedThrowingContinuation { cont in
            discoveryContinuation = cont
            Task {
                try await Task.sleep(for: .seconds(timeout))
                if self.discoveryContinuation != nil {
                    self.central.stopScan()
                    self.discoveryContinuation?.resume(throwing: WatchBLEError.scanTimedOut)
                    self.discoveryContinuation = nil
                }
            }
        }
    }

    /// Connects to the discovered peripheral and waits until the HR characteristic is ready
    /// and notifications are subscribed.
    public func connect(to device: BLEDevice) async throws {
        guard let peripheral = connectedPeripheral, peripheral.identifier == device.identifier else {
            throw WatchBLEError.connectionFailed("Peripheral \(device.identifier) not in cache.")
        }
        try await withCheckedThrowingContinuation { cont in
            connectContinuation = cont
            central.connect(peripheral, options: nil)
        }
    }

    /// Suspends until the next Heart Rate Measurement GATT notification arrives.
    ///
    /// Call this after `connect(to:)` has returned. Each call returns exactly one BPM reading.
    public func readHeartRate() async throws -> Int {
        try await withCheckedThrowingContinuation { cont in
            hrContinuation = cont
        }
    }

    /// Disconnects the active peripheral.
    public func disconnect() {
        if let p = connectedPeripheral {
            central.cancelPeripheralConnection(p)
        }
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            powerOnContinuation?.resume()
            powerOnContinuation = nil
        case .poweredOff, .unauthorized, .unsupported:
            powerOnContinuation?.resume(throwing: WatchBLEError.radioPoweredOff)
            powerOnContinuation = nil
        default:
            break
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
        let device = BLEDevice(identifier: peripheral.identifier, name: peripheral.name ?? "Unknown Watch")
        discoveryContinuation?.resume(returning: device)
        discoveryContinuation = nil
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([WatchBLEBridge.heartRateServiceUUID])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectContinuation?.resume(
            throwing: WatchBLEError.connectionFailed(error?.localizedDescription ?? "Unknown error")
        )
        connectContinuation = nil
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            connectContinuation?.resume(throwing: WatchBLEError.connectionFailed(error.localizedDescription))
            connectContinuation = nil
            return
        }
        guard let hrService = peripheral.services?.first(where: {
            $0.uuid == WatchBLEBridge.heartRateServiceUUID
        }) else {
            connectContinuation?.resume(throwing: WatchBLEError.missingHRService)
            connectContinuation = nil
            return
        }
        peripheral.discoverCharacteristics([WatchBLEBridge.heartRateMeasurementUUID], for: hrService)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            connectContinuation?.resume(throwing: WatchBLEError.connectionFailed(error.localizedDescription))
            connectContinuation = nil
            return
        }
        guard let char = service.characteristics?.first(where: {
            $0.uuid == WatchBLEBridge.heartRateMeasurementUUID
        }) else {
            connectContinuation?.resume(throwing: WatchBLEError.missingHRCharacteristic)
            connectContinuation = nil
            return
        }
        hrCharacteristic = char
        peripheral.setNotifyValue(true, for: char)
        // Consider connected once notifications are enabled.
        connectContinuation?.resume()
        connectContinuation = nil
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == WatchBLEBridge.heartRateMeasurementUUID else { return }
        let bpm = decodeBPM(from: characteristic.value)
        let reading = HeartRateReading(bpm: bpm)
        collectedReadings.append(reading)
        hrContinuation?.resume(returning: bpm)
        hrContinuation = nil
    }

    // MARK: - GATT Decoding

    /// Decodes a BPM value from a Heart Rate Measurement characteristic value.
    ///
    /// Per the GATT specification (Heart Rate Profile v1.0):
    /// - Byte 0: flags  (bit 0 = 0 → 8-bit BPM; bit 0 = 1 → 16-bit BPM, little-endian)
    /// - Byte 1 (or bytes 1–2): BPM value
    private func decodeBPM(from data: Data?) -> Int {
        guard let data, data.count >= 2 else { return 0 }
        let flags = data[0]
        if flags & 0x01 == 0 {
            return Int(data[1])
        } else {
            guard data.count >= 3 else { return Int(data[1]) }
            return Int(data[1]) | (Int(data[2]) << 8)
        }
    }
}

// MARK: - BLEClient Live

public extension BLEClient {
    /// Creates the live CoreBluetooth implementation that drives a watch peripheral.
    ///
    /// Pass the same `bridge` to `WatchCoordinator` so hardware events (peripheral
    /// discovery, HR notifications) can be awaited from the coordinator side.
    static func makeLive(bridge: WatchBLEBridge = WatchBLEBridge()) -> Self {
        .runtime(handlers: WatchBLERuntimeHandlers(
            startScan: {
                // Suspends until the radio is ready, then kicks off a peripheral scan.
                try await bridge.waitForPoweredOn()
                bridge.startScanning()
            },
            watchDiscovered: { device in
                // Connects and waits until the HR GATT characteristic is subscribed.
                try await bridge.connect(to: device)
            },
            powerDown: {
                bridge.disconnect()
            }
        ))
    }
}

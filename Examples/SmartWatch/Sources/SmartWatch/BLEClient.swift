import Foundation
import Dependencies

// MARK: - BLE Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct BLEClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> WatchBLEContext
    typealias StartScanTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias WatchDiscoveredBLEDeviceTransition = @Sendable (WatchBLEContext, BLEDevice) async throws -> WatchBLEContext
    typealias ScanTimeoutTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias CancelScanTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias ConnectionEstablishedTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias ConnectionFailedStringTransition = @Sendable (WatchBLEContext, String) async throws -> WatchBLEContext
    typealias RetryTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias RetriesExhaustedTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias PeripheralDisconnectedTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias UserDisconnectedTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias ResetAndScanTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    typealias PowerDownTransition = @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    let initialContext: InitialContextBuilder
    let startScanTransition: StartScanTransition
    let watchDiscoveredBLEDeviceTransition: WatchDiscoveredBLEDeviceTransition
    let scanTimeoutTransition: ScanTimeoutTransition
    let cancelScanTransition: CancelScanTransition
    let connectionEstablishedTransition: ConnectionEstablishedTransition
    let connectionFailedStringTransition: ConnectionFailedStringTransition
    let retryTransition: RetryTransition
    let retriesExhaustedTransition: RetriesExhaustedTransition
    let peripheralDisconnectedTransition: PeripheralDisconnectedTransition
    let userDisconnectedTransition: UserDisconnectedTransition
    let resetAndScanTransition: ResetAndScanTransition
    let powerDownTransition: PowerDownTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        startScanTransition: @escaping StartScanTransition,
        watchDiscoveredBLEDeviceTransition: @escaping WatchDiscoveredBLEDeviceTransition,
        scanTimeoutTransition: @escaping ScanTimeoutTransition,
        cancelScanTransition: @escaping CancelScanTransition,
        connectionEstablishedTransition: @escaping ConnectionEstablishedTransition,
        connectionFailedStringTransition: @escaping ConnectionFailedStringTransition,
        retryTransition: @escaping RetryTransition,
        retriesExhaustedTransition: @escaping RetriesExhaustedTransition,
        peripheralDisconnectedTransition: @escaping PeripheralDisconnectedTransition,
        userDisconnectedTransition: @escaping UserDisconnectedTransition,
        resetAndScanTransition: @escaping ResetAndScanTransition,
        powerDownTransition: @escaping PowerDownTransition
    ) {
        self.initialContext = initialContext
        self.startScanTransition = startScanTransition
        self.watchDiscoveredBLEDeviceTransition = watchDiscoveredBLEDeviceTransition
        self.scanTimeoutTransition = scanTimeoutTransition
        self.cancelScanTransition = cancelScanTransition
        self.connectionEstablishedTransition = connectionEstablishedTransition
        self.connectionFailedStringTransition = connectionFailedStringTransition
        self.retryTransition = retryTransition
        self.retriesExhaustedTransition = retriesExhaustedTransition
        self.peripheralDisconnectedTransition = peripheralDisconnectedTransition
        self.userDisconnectedTransition = userDisconnectedTransition
        self.resetAndScanTransition = resetAndScanTransition
        self.powerDownTransition = powerDownTransition
    }
}

extension BLEClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: BLEClientRuntime) -> Self {
        Self(
            makeWatchBLE: {
                let context = runtime.initialContext()
                return BLEMachine<BLEStateOff>(
                    internalContext: context,
                _startScan: runtime.startScanTransition,
                _watchDiscoveredBLEDevice: runtime.watchDiscoveredBLEDeviceTransition,
                _scanTimeout: runtime.scanTimeoutTransition,
                _cancelScan: runtime.cancelScanTransition,
                _connectionEstablished: runtime.connectionEstablishedTransition,
                _connectionFailedString: runtime.connectionFailedStringTransition,
                _retry: runtime.retryTransition,
                _retriesExhausted: runtime.retriesExhaustedTransition,
                _peripheralDisconnected: runtime.peripheralDisconnectedTransition,
                _userDisconnected: runtime.userDisconnectedTransition,
                _resetAndScan: runtime.resetAndScanTransition,
                _powerDown: runtime.powerDownTransition
                )
            }
        )
    }
}

// MARK: - BLE Client

/// Dependency client entry point for constructing BLE state machines.
public struct BLEClient: Sendable {
    public var makeWatchBLE: @Sendable () -> BLEMachine<BLEStateOff>

    public init(makeWatchBLE: @escaping @Sendable () -> BLEMachine<BLEStateOff>) {
        self.makeWatchBLE = makeWatchBLE
    }
}
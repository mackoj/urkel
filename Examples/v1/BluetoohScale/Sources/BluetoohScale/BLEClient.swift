import Foundation
import Dependencies

// MARK: - BLE Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct BLEClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> BLEContext
    typealias PowerOnTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias RadioReadyTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias DeviceDiscoveredBLEDeviceTransition = @Sendable (BLEContext, BLEDevice) async throws -> BLEContext
    typealias ScanTimeoutTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias ConnectionEstablishedTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias ConnectionFailedStringTransition = @Sendable (BLEContext, String) async throws -> BLEContext
    typealias RetryTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias RetriesExhaustedTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias StartSyncScalePayloadTransition = @Sendable (BLEContext, ScalePayload) async throws -> BLEContext
    typealias SyncSucceededTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias SyncFailedStringTransition = @Sendable (BLEContext, String) async throws -> BLEContext
    typealias PeripheralDisconnectedTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias ResetRadioTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias PowerDownTransition = @Sendable (BLEContext) async throws -> BLEContext
    let initialContext: InitialContextBuilder
    let powerOnTransition: PowerOnTransition
    let radioReadyTransition: RadioReadyTransition
    let deviceDiscoveredBLEDeviceTransition: DeviceDiscoveredBLEDeviceTransition
    let scanTimeoutTransition: ScanTimeoutTransition
    let connectionEstablishedTransition: ConnectionEstablishedTransition
    let connectionFailedStringTransition: ConnectionFailedStringTransition
    let retryTransition: RetryTransition
    let retriesExhaustedTransition: RetriesExhaustedTransition
    let startSyncScalePayloadTransition: StartSyncScalePayloadTransition
    let syncSucceededTransition: SyncSucceededTransition
    let syncFailedStringTransition: SyncFailedStringTransition
    let peripheralDisconnectedTransition: PeripheralDisconnectedTransition
    let resetRadioTransition: ResetRadioTransition
    let powerDownTransition: PowerDownTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        powerOnTransition: @escaping PowerOnTransition,
        radioReadyTransition: @escaping RadioReadyTransition,
        deviceDiscoveredBLEDeviceTransition: @escaping DeviceDiscoveredBLEDeviceTransition,
        scanTimeoutTransition: @escaping ScanTimeoutTransition,
        connectionEstablishedTransition: @escaping ConnectionEstablishedTransition,
        connectionFailedStringTransition: @escaping ConnectionFailedStringTransition,
        retryTransition: @escaping RetryTransition,
        retriesExhaustedTransition: @escaping RetriesExhaustedTransition,
        startSyncScalePayloadTransition: @escaping StartSyncScalePayloadTransition,
        syncSucceededTransition: @escaping SyncSucceededTransition,
        syncFailedStringTransition: @escaping SyncFailedStringTransition,
        peripheralDisconnectedTransition: @escaping PeripheralDisconnectedTransition,
        resetRadioTransition: @escaping ResetRadioTransition,
        powerDownTransition: @escaping PowerDownTransition
    ) {
        self.initialContext = initialContext
        self.powerOnTransition = powerOnTransition
        self.radioReadyTransition = radioReadyTransition
        self.deviceDiscoveredBLEDeviceTransition = deviceDiscoveredBLEDeviceTransition
        self.scanTimeoutTransition = scanTimeoutTransition
        self.connectionEstablishedTransition = connectionEstablishedTransition
        self.connectionFailedStringTransition = connectionFailedStringTransition
        self.retryTransition = retryTransition
        self.retriesExhaustedTransition = retriesExhaustedTransition
        self.startSyncScalePayloadTransition = startSyncScalePayloadTransition
        self.syncSucceededTransition = syncSucceededTransition
        self.syncFailedStringTransition = syncFailedStringTransition
        self.peripheralDisconnectedTransition = peripheralDisconnectedTransition
        self.resetRadioTransition = resetRadioTransition
        self.powerDownTransition = powerDownTransition
    }
}

extension BLEClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: BLEClientRuntime) -> Self {
        Self(
            makeBLE: {
                let context = runtime.initialContext()
                return BLEMachine<BLEStateOff>(
                    internalContext: context,
                _powerOn: runtime.powerOnTransition,
                _radioReady: runtime.radioReadyTransition,
                _deviceDiscoveredBLEDevice: runtime.deviceDiscoveredBLEDeviceTransition,
                _scanTimeout: runtime.scanTimeoutTransition,
                _connectionEstablished: runtime.connectionEstablishedTransition,
                _connectionFailedString: runtime.connectionFailedStringTransition,
                _retry: runtime.retryTransition,
                _retriesExhausted: runtime.retriesExhaustedTransition,
                _startSyncScalePayload: runtime.startSyncScalePayloadTransition,
                _syncSucceeded: runtime.syncSucceededTransition,
                _syncFailedString: runtime.syncFailedStringTransition,
                _peripheralDisconnected: runtime.peripheralDisconnectedTransition,
                _resetRadio: runtime.resetRadioTransition,
                _powerDown: runtime.powerDownTransition
                )
            }
        )
    }
}

// MARK: - BLE Client

/// Dependency client entry point for constructing BLE state machines.
public struct BLEClient: Sendable {
    public var makeBLE: @Sendable () -> BLEMachine<BLEStateOff>

    public init(makeBLE: @escaping @Sendable () -> BLEMachine<BLEStateOff>) {
        self.makeBLE = makeBLE
    }
}
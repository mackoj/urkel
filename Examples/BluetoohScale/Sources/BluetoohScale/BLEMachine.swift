import Foundation
import Dependencies

// MARK: - BLE Typestate Markers

public enum BLEStateOff {}
public enum BLEStateWakingRadio {}
public enum BLEStateScanning {}
public enum BLEStateConnecting {}
public enum BLEStateConnected {}
public enum BLEStateReconnecting {}
public enum BLEStateSyncing {}
public enum BLEStateError {}
public enum BLEStatePoweredDown {}

// MARK: - BLE State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct BLEMachine<State>: ~Copyable {
    private var internalContext: BLEContext

    private let _powerOn: @Sendable (BLEContext) async throws -> BLEContext
    private let _radioReady: @Sendable (BLEContext) async throws -> BLEContext
    private let _deviceDiscoveredBLEDevice: @Sendable (BLEContext, BLEDevice) async throws -> BLEContext
    private let _scanTimeout: @Sendable (BLEContext) async throws -> BLEContext
    private let _connectionEstablished: @Sendable (BLEContext) async throws -> BLEContext
    private let _connectionFailedString: @Sendable (BLEContext, String) async throws -> BLEContext
    private let _retry: @Sendable (BLEContext) async throws -> BLEContext
    private let _retriesExhausted: @Sendable (BLEContext) async throws -> BLEContext
    private let _startSyncScalePayload: @Sendable (BLEContext, ScalePayload) async throws -> BLEContext
    private let _syncSucceeded: @Sendable (BLEContext) async throws -> BLEContext
    private let _syncFailedString: @Sendable (BLEContext, String) async throws -> BLEContext
    private let _peripheralDisconnected: @Sendable (BLEContext) async throws -> BLEContext
    private let _resetRadio: @Sendable (BLEContext) async throws -> BLEContext
    private let _powerDown: @Sendable (BLEContext) async throws -> BLEContext
    public init(
        internalContext: BLEContext,
        _powerOn: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _radioReady: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _deviceDiscoveredBLEDevice: @escaping @Sendable (BLEContext, BLEDevice) async throws -> BLEContext,
        _scanTimeout: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _connectionEstablished: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _connectionFailedString: @escaping @Sendable (BLEContext, String) async throws -> BLEContext,
        _retry: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _retriesExhausted: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _startSyncScalePayload: @escaping @Sendable (BLEContext, ScalePayload) async throws -> BLEContext,
        _syncSucceeded: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _syncFailedString: @escaping @Sendable (BLEContext, String) async throws -> BLEContext,
        _peripheralDisconnected: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _resetRadio: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _powerDown: @escaping @Sendable (BLEContext) async throws -> BLEContext
    ) {
        self.internalContext = internalContext

        self._powerOn = _powerOn
        self._radioReady = _radioReady
        self._deviceDiscoveredBLEDevice = _deviceDiscoveredBLEDevice
        self._scanTimeout = _scanTimeout
        self._connectionEstablished = _connectionEstablished
        self._connectionFailedString = _connectionFailedString
        self._retry = _retry
        self._retriesExhausted = _retriesExhausted
        self._startSyncScalePayload = _startSyncScalePayload
        self._syncSucceeded = _syncSucceeded
        self._syncFailedString = _syncFailedString
        self._peripheralDisconnected = _peripheralDisconnected
        self._resetRadio = _resetRadio
        self._powerDown = _powerDown
    }

    /// Access the internal context while preserving borrowing semantics.
    public borrowing func withInternalContext<R>(_ body: (borrowing BLEContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - BLE.Off Transitions

extension BLEMachine where State == BLEStateOff {
    /// Handles the `powerOn` transition from Off to WakingRadio.
    public consuming func powerOn() async throws -> BLEMachine<BLEStateWakingRadio> {
        let nextContext = try await self._powerOn(self.internalContext)
        return BLEMachine<BLEStateWakingRadio>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.WakingRadio Transitions

extension BLEMachine where State == BLEStateWakingRadio {
    /// Handles the `radioReady` transition from WakingRadio to Scanning.
    public consuming func radioReady() async throws -> BLEMachine<BLEStateScanning> {
        let nextContext = try await self._radioReady(self.internalContext)
        return BLEMachine<BLEStateScanning>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Scanning Transitions

extension BLEMachine where State == BLEStateScanning {
    /// Handles the `deviceDiscovered` transition from Scanning to Connecting.
    public consuming func deviceDiscovered(device: BLEDevice) async throws -> BLEMachine<BLEStateConnecting> {
        let nextContext = try await self._deviceDiscoveredBLEDevice(self.internalContext, device)
        return BLEMachine<BLEStateConnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `scanTimeout` transition from Scanning to Error.
    public consuming func scanTimeout() async throws -> BLEMachine<BLEStateError> {
        let nextContext = try await self._scanTimeout(self.internalContext)
        return BLEMachine<BLEStateError>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Connecting Transitions

extension BLEMachine where State == BLEStateConnecting {
    /// Handles the `connectionEstablished` transition from Connecting to Connected.
    public consuming func connectionEstablished() async throws -> BLEMachine<BLEStateConnected> {
        let nextContext = try await self._connectionEstablished(self.internalContext)
        return BLEMachine<BLEStateConnected>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `connectionFailed` transition from Connecting to Reconnecting.
    public consuming func connectionFailed(reason: String) async throws -> BLEMachine<BLEStateReconnecting> {
        let nextContext = try await self._connectionFailedString(self.internalContext, reason)
        return BLEMachine<BLEStateReconnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Reconnecting Transitions

extension BLEMachine where State == BLEStateReconnecting {
    /// Handles the `retry` transition from Reconnecting to Connecting.
    public consuming func retry() async throws -> BLEMachine<BLEStateConnecting> {
        let nextContext = try await self._retry(self.internalContext)
        return BLEMachine<BLEStateConnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `retriesExhausted` transition from Reconnecting to Error.
    public consuming func retriesExhausted() async throws -> BLEMachine<BLEStateError> {
        let nextContext = try await self._retriesExhausted(self.internalContext)
        return BLEMachine<BLEStateError>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Reconnecting to PoweredDown.
    public consuming func powerDown() async throws -> BLEMachine<BLEStatePoweredDown> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEMachine<BLEStatePoweredDown>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Connected Transitions

extension BLEMachine where State == BLEStateConnected {
    /// Handles the `startSync` transition from Connected to Syncing.
    public consuming func startSync(payload: ScalePayload) async throws -> BLEMachine<BLEStateSyncing> {
        let nextContext = try await self._startSyncScalePayload(self.internalContext, payload)
        return BLEMachine<BLEStateSyncing>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `peripheralDisconnected` transition from Connected to Reconnecting.
    public consuming func peripheralDisconnected() async throws -> BLEMachine<BLEStateReconnecting> {
        let nextContext = try await self._peripheralDisconnected(self.internalContext)
        return BLEMachine<BLEStateReconnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Connected to PoweredDown.
    public consuming func powerDown() async throws -> BLEMachine<BLEStatePoweredDown> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEMachine<BLEStatePoweredDown>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Syncing Transitions

extension BLEMachine where State == BLEStateSyncing {
    /// Handles the `syncSucceeded` transition from Syncing to Connected.
    public consuming func syncSucceeded() async throws -> BLEMachine<BLEStateConnected> {
        let nextContext = try await self._syncSucceeded(self.internalContext)
        return BLEMachine<BLEStateConnected>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `syncFailed` transition from Syncing to Reconnecting.
    public consuming func syncFailed(reason: String) async throws -> BLEMachine<BLEStateReconnecting> {
        let nextContext = try await self._syncFailedString(self.internalContext, reason)
        return BLEMachine<BLEStateReconnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Error Transitions

extension BLEMachine where State == BLEStateError {
    /// Handles the `resetRadio` transition from Error to Off.
    public consuming func resetRadio() async throws -> BLEMachine<BLEStateOff> {
        let nextContext = try await self._resetRadio(self.internalContext)
        return BLEMachine<BLEStateOff>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Error to PoweredDown.
    public consuming func powerDown() async throws -> BLEMachine<BLEStatePoweredDown> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEMachine<BLEStatePoweredDown>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredBLEDevice: self._deviceDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncScalePayload: self._startSyncScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedString: self._syncFailedString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE Combined State

/// A runtime-friendly wrapper over all observer states.
public enum BLEState: ~Copyable {
    case off(BLEMachine<BLEStateOff>)
    case wakingRadio(BLEMachine<BLEStateWakingRadio>)
    case scanning(BLEMachine<BLEStateScanning>)
    case connecting(BLEMachine<BLEStateConnecting>)
    case connected(BLEMachine<BLEStateConnected>)
    case reconnecting(BLEMachine<BLEStateReconnecting>)
    case syncing(BLEMachine<BLEStateSyncing>)
    case error(BLEMachine<BLEStateError>)
    case poweredDown(BLEMachine<BLEStatePoweredDown>)

    public init(_ machine: consuming BLEMachine<BLEStateOff>) {
        self = .off(machine)
    }
}

extension BLEState {
    public borrowing func withOff<R>(_ body: (borrowing BLEMachine<BLEStateOff>) throws -> R) rethrows -> R? {
        switch self {
        case let .off(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withWakingRadio<R>(_ body: (borrowing BLEMachine<BLEStateWakingRadio>) throws -> R) rethrows -> R? {
        switch self {
        case let .wakingRadio(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withScanning<R>(_ body: (borrowing BLEMachine<BLEStateScanning>) throws -> R) rethrows -> R? {
        switch self {
        case let .scanning(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withConnecting<R>(_ body: (borrowing BLEMachine<BLEStateConnecting>) throws -> R) rethrows -> R? {
        switch self {
        case let .connecting(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withConnected<R>(_ body: (borrowing BLEMachine<BLEStateConnected>) throws -> R) rethrows -> R? {
        switch self {
        case let .connected(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withReconnecting<R>(_ body: (borrowing BLEMachine<BLEStateReconnecting>) throws -> R) rethrows -> R? {
        switch self {
        case let .reconnecting(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withSyncing<R>(_ body: (borrowing BLEMachine<BLEStateSyncing>) throws -> R) rethrows -> R? {
        switch self {
        case let .syncing(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withError<R>(_ body: (borrowing BLEMachine<BLEStateError>) throws -> R) rethrows -> R? {
        switch self {
        case let .error(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withPoweredDown<R>(_ body: (borrowing BLEMachine<BLEStatePoweredDown>) throws -> R) rethrows -> R? {
        switch self {
        case let .poweredDown(observer):
            return try body(observer)
        default:
            return nil
        }
    }


    /// Attempts the `powerOn` transition from the current wrapper state.
    public consuming func powerOn() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .wakingRadio(try await observer.powerOn())
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `radioReady` transition from the current wrapper state.
    public consuming func radioReady() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .scanning(try await observer.radioReady())
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `deviceDiscovered` transition from the current wrapper state.
    public consuming func deviceDiscovered(device: BLEDevice) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .connecting(try await observer.deviceDiscovered(device: device))
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `scanTimeout` transition from the current wrapper state.
    public consuming func scanTimeout() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .error(try await observer.scanTimeout())
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `connectionEstablished` transition from the current wrapper state.
    public consuming func connectionEstablished() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connected(try await observer.connectionEstablished())
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `connectionFailed` transition from the current wrapper state.
    public consuming func connectionFailed(reason: String) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .reconnecting(try await observer.connectionFailed(reason: reason))
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `retry` transition from the current wrapper state.
    public consuming func retry() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .connecting(try await observer.retry())
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `retriesExhausted` transition from the current wrapper state.
    public consuming func retriesExhausted() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .error(try await observer.retriesExhausted())
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `startSync` transition from the current wrapper state.
    public consuming func startSync(payload: ScalePayload) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .syncing(try await observer.startSync(payload: payload))
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `syncSucceeded` transition from the current wrapper state.
    public consuming func syncSucceeded() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .connected(try await observer.syncSucceeded())
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `syncFailed` transition from the current wrapper state.
    public consuming func syncFailed(reason: String) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .reconnecting(try await observer.syncFailed(reason: reason))
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `peripheralDisconnected` transition from the current wrapper state.
    public consuming func peripheralDisconnected() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .reconnecting(try await observer.peripheralDisconnected())
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .error(observer)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `resetRadio` transition from the current wrapper state.
    public consuming func resetRadio() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .off(try await observer.resetRadio())
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }

    /// Attempts the `powerDown` transition from the current wrapper state.
    public consuming func powerDown() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingRadio(observer):
        return .wakingRadio(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .poweredDown(try await observer.powerDown())
    case let .reconnecting(observer):
        return .poweredDown(try await observer.powerDown())
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        return .poweredDown(try await observer.powerDown())
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }
}
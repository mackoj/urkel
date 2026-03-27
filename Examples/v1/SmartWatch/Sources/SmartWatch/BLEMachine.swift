import Foundation
import Dependencies

// MARK: - BLE Typestate Markers

public enum BLEStateOff {}
public enum BLEStateScanning {}
public enum BLEStateConnecting {}
public enum BLEStateConnected {}
public enum BLEStateReconnecting {}
public enum BLEStateError {}
public enum BLEStateDisconnected {}

// MARK: - BLE State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct BLEMachine<State>: ~Copyable {
    private var internalContext: WatchBLEContext

    fileprivate let _startScan: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _watchDiscoveredBLEDevice: @Sendable (WatchBLEContext, BLEDevice) async throws -> WatchBLEContext
    fileprivate let _scanTimeout: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _cancelScan: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _connectionEstablished: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _connectionFailedString: @Sendable (WatchBLEContext, String) async throws -> WatchBLEContext
    fileprivate let _retry: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _retriesExhausted: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _peripheralDisconnected: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _userDisconnected: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _resetAndScan: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    fileprivate let _powerDown: @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    internal init(
        internalContext: WatchBLEContext,
        _startScan: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _watchDiscoveredBLEDevice: @escaping @Sendable (WatchBLEContext, BLEDevice) async throws -> WatchBLEContext,
        _scanTimeout: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _cancelScan: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _connectionEstablished: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _connectionFailedString: @escaping @Sendable (WatchBLEContext, String) async throws -> WatchBLEContext,
        _retry: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _retriesExhausted: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _peripheralDisconnected: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _userDisconnected: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _resetAndScan: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext,
        _powerDown: @escaping @Sendable (WatchBLEContext) async throws -> WatchBLEContext
    ) {
        self.internalContext = internalContext

        self._startScan = _startScan
        self._watchDiscoveredBLEDevice = _watchDiscoveredBLEDevice
        self._scanTimeout = _scanTimeout
        self._cancelScan = _cancelScan
        self._connectionEstablished = _connectionEstablished
        self._connectionFailedString = _connectionFailedString
        self._retry = _retry
        self._retriesExhausted = _retriesExhausted
        self._peripheralDisconnected = _peripheralDisconnected
        self._userDisconnected = _userDisconnected
        self._resetAndScan = _resetAndScan
        self._powerDown = _powerDown
    }

    /// Access the internal context while preserving borrowing semantics.
    internal borrowing func withInternalContext<R>(_ body: (borrowing WatchBLEContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - BLE.Off Transitions

extension BLEMachine where State == BLEStateOff {
    /// Power on the BLE radio and start scanning for the watch peripheral
    public consuming func startScan() async throws -> BLEMachine<BLEStateScanning> {
        let nextContext = try await self._startScan(self.internalContext)
        return BLEMachine<BLEStateScanning>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Scanning Transitions

extension BLEMachine where State == BLEStateScanning {
    /// A watch peripheral was discovered; attempt to connect
    public consuming func watchDiscovered(device: BLEDevice) async throws -> BLEMachine<BLEStateConnecting> {
        let nextContext = try await self._watchDiscoveredBLEDevice(self.internalContext, device)
        return BLEMachine<BLEStateConnecting>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// Scan timed out without finding a peripheral
    public consuming func scanTimeout() async throws -> BLEMachine<BLEStateError> {
        let nextContext = try await self._scanTimeout(self.internalContext)
        return BLEMachine<BLEStateError>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// User cancelled the scan before a device was found
    public consuming func cancelScan() async throws -> BLEMachine<BLEStateOff> {
        let nextContext = try await self._cancelScan(self.internalContext)
        return BLEMachine<BLEStateOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Connecting Transitions

extension BLEMachine where State == BLEStateConnecting {
    /// Physical connection and GATT characteristic discovery succeeded
    public consuming func connectionEstablished() async throws -> BLEMachine<BLEStateConnected> {
        let nextContext = try await self._connectionEstablished(self.internalContext)
        return BLEMachine<BLEStateConnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// Connection attempt failed; enter retry loop
    public consuming func connectionFailed(reason: String) async throws -> BLEMachine<BLEStateReconnecting> {
        let nextContext = try await self._connectionFailedString(self.internalContext, reason)
        return BLEMachine<BLEStateReconnecting>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Reconnecting Transitions

extension BLEMachine where State == BLEStateReconnecting {
    /// Retry the connection (called after a back-off delay)
    public consuming func retry() async throws -> BLEMachine<BLEStateConnecting> {
        let nextContext = try await self._retry(self.internalContext)
        return BLEMachine<BLEStateConnecting>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// All retries exhausted; surface the error
    public consuming func retriesExhausted() async throws -> BLEMachine<BLEStateError> {
        let nextContext = try await self._retriesExhausted(self.internalContext)
        return BLEMachine<BLEStateError>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Reconnecting to Disconnected.
    public consuming func powerDown() async throws -> BLEMachine<BLEStateDisconnected> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEMachine<BLEStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Connected Transitions

extension BLEMachine where State == BLEStateConnected {
    /// Watch dropped the link; enter reconnect loop
    public consuming func peripheralDisconnected() async throws -> BLEMachine<BLEStateReconnecting> {
        let nextContext = try await self._peripheralDisconnected(self.internalContext)
        return BLEMachine<BLEStateReconnecting>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// User explicitly disconnected; return to idle
    public consuming func userDisconnected() async throws -> BLEMachine<BLEStateOff> {
        let nextContext = try await self._userDisconnected(self.internalContext)
        return BLEMachine<BLEStateOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// Graceful power-down from any live state
    public consuming func powerDown() async throws -> BLEMachine<BLEStateDisconnected> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEMachine<BLEStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Error Transitions

extension BLEMachine where State == BLEStateError {
    /// Reset BLE radio and try scanning again
    public consuming func resetAndScan() async throws -> BLEMachine<BLEStateOff> {
        let nextContext = try await self._resetAndScan(self.internalContext)
        return BLEMachine<BLEStateOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Error to Disconnected.
    public consuming func powerDown() async throws -> BLEMachine<BLEStateDisconnected> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEMachine<BLEStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _watchDiscoveredBLEDevice: self._watchDiscoveredBLEDevice,
                _scanTimeout: self._scanTimeout,
                _cancelScan: self._cancelScan,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedString: self._connectionFailedString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _peripheralDisconnected: self._peripheralDisconnected,
                _userDisconnected: self._userDisconnected,
                _resetAndScan: self._resetAndScan,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE Combined State

/// A runtime-friendly wrapper over all observer states.
public enum BLEState: ~Copyable {
    case off(BLEMachine<BLEStateOff>)
    case scanning(BLEMachine<BLEStateScanning>)
    case connecting(BLEMachine<BLEStateConnecting>)
    case connected(BLEMachine<BLEStateConnected>)
    case reconnecting(BLEMachine<BLEStateReconnecting>)
    case error(BLEMachine<BLEStateError>)
    case disconnected(BLEMachine<BLEStateDisconnected>)

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

    public borrowing func withError<R>(_ body: (borrowing BLEMachine<BLEStateError>) throws -> R) rethrows -> R? {
        switch self {
        case let .error(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withDisconnected<R>(_ body: (borrowing BLEMachine<BLEStateDisconnected>) throws -> R) rethrows -> R? {
        switch self {
        case let .disconnected(observer):
            return try body(observer)
        default:
            return nil
        }
    }


    /// Attempts the `startScan` transition from the current wrapper state.
    public consuming func startScan() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .scanning(try await observer.startScan())
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `watchDiscovered` transition from the current wrapper state.
    public consuming func watchDiscovered(device: BLEDevice) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .connecting(try await observer.watchDiscovered(device: device))
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `scanTimeout` transition from the current wrapper state.
    public consuming func scanTimeout() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .error(try await observer.scanTimeout())
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `cancelScan` transition from the current wrapper state.
    public consuming func cancelScan() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .off(try await observer.cancelScan())
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `connectionEstablished` transition from the current wrapper state.
    public consuming func connectionEstablished() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connected(try await observer.connectionEstablished())
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `connectionFailed` transition from the current wrapper state.
    public consuming func connectionFailed(reason: String) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .reconnecting(try await observer.connectionFailed(reason: reason))
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `retry` transition from the current wrapper state.
    public consuming func retry() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .connecting(try await observer.retry())
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `retriesExhausted` transition from the current wrapper state.
    public consuming func retriesExhausted() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .error(try await observer.retriesExhausted())
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `peripheralDisconnected` transition from the current wrapper state.
    public consuming func peripheralDisconnected() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .reconnecting(try await observer.peripheralDisconnected())
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `userDisconnected` transition from the current wrapper state.
    public consuming func userDisconnected() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .off(try await observer.userDisconnected())
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .error(observer)
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `resetAndScan` transition from the current wrapper state.
    public consuming func resetAndScan() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .connected(observer)
    case let .reconnecting(observer):
        return .reconnecting(observer)
    case let .error(observer):
        return .off(try await observer.resetAndScan())
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }

    /// Attempts the `powerDown` transition from the current wrapper state.
    public consuming func powerDown() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connected(observer):
        return .disconnected(try await observer.powerDown())
    case let .reconnecting(observer):
        return .disconnected(try await observer.powerDown())
    case let .error(observer):
        return .disconnected(try await observer.powerDown())
    case let .disconnected(observer):
        return .disconnected(observer)
        }
    }
}
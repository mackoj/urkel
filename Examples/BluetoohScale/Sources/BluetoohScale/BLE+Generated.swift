import Foundation
import Dependencies

// MARK: - BLE State Machine

/// Typestate markers for the `BLE` machine.
public enum BLEMachine {
    public enum Off {}
    public enum WakingRadio {}
    public enum Scanning {}
    public enum Connecting {}
    public enum Connected {}
    public enum Reconnecting {}
    public enum Syncing {}
    public enum Error {}
    public enum PoweredDown {}
}

// MARK: - BLE Observer

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct BLEObserver<State>: ~Copyable {
    private var internalContext: BLEContext

    private let _powerOn: @Sendable (BLEContext) async throws -> BLEContext
    private let _radioReady: @Sendable (BLEContext) async throws -> BLEContext
    private let _deviceDiscoveredDeviceBLEDevice: @Sendable (BLEContext, BLEDevice) async throws -> BLEContext
    private let _scanTimeout: @Sendable (BLEContext) async throws -> BLEContext
    private let _connectionEstablished: @Sendable (BLEContext) async throws -> BLEContext
    private let _connectionFailedReasonString: @Sendable (BLEContext, String) async throws -> BLEContext
    private let _retry: @Sendable (BLEContext) async throws -> BLEContext
    private let _retriesExhausted: @Sendable (BLEContext) async throws -> BLEContext
    private let _startSyncPayloadScalePayload: @Sendable (BLEContext, ScalePayload) async throws -> BLEContext
    private let _syncSucceeded: @Sendable (BLEContext) async throws -> BLEContext
    private let _syncFailedReasonString: @Sendable (BLEContext, String) async throws -> BLEContext
    private let _peripheralDisconnected: @Sendable (BLEContext) async throws -> BLEContext
    private let _resetRadio: @Sendable (BLEContext) async throws -> BLEContext
    private let _powerDown: @Sendable (BLEContext) async throws -> BLEContext
    public init(
        internalContext: BLEContext,
        _powerOn: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _radioReady: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _deviceDiscoveredDeviceBLEDevice: @escaping @Sendable (BLEContext, BLEDevice) async throws -> BLEContext,
        _scanTimeout: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _connectionEstablished: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _connectionFailedReasonString: @escaping @Sendable (BLEContext, String) async throws -> BLEContext,
        _retry: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _retriesExhausted: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _startSyncPayloadScalePayload: @escaping @Sendable (BLEContext, ScalePayload) async throws -> BLEContext,
        _syncSucceeded: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _syncFailedReasonString: @escaping @Sendable (BLEContext, String) async throws -> BLEContext,
        _peripheralDisconnected: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _resetRadio: @escaping @Sendable (BLEContext) async throws -> BLEContext,
        _powerDown: @escaping @Sendable (BLEContext) async throws -> BLEContext
    ) {
        self.internalContext = internalContext

        self._powerOn = _powerOn
        self._radioReady = _radioReady
        self._deviceDiscoveredDeviceBLEDevice = _deviceDiscoveredDeviceBLEDevice
        self._scanTimeout = _scanTimeout
        self._connectionEstablished = _connectionEstablished
        self._connectionFailedReasonString = _connectionFailedReasonString
        self._retry = _retry
        self._retriesExhausted = _retriesExhausted
        self._startSyncPayloadScalePayload = _startSyncPayloadScalePayload
        self._syncSucceeded = _syncSucceeded
        self._syncFailedReasonString = _syncFailedReasonString
        self._peripheralDisconnected = _peripheralDisconnected
        self._resetRadio = _resetRadio
        self._powerDown = _powerDown
    }

    /// Access the internal context while preserving borrowing semantics.
    public borrowing func withInternalContext<R>(_ body: (borrowing BLEContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - BLE Runtime Stream

/// Generic stream lifecycle helper for event-driven runtimes generated from this machine.
actor BLERuntimeStream<Element: Sendable> {
    nonisolated let events: AsyncThrowingStream<Element, Error>

    private var continuation: AsyncThrowingStream<Element, Error>.Continuation?
    private var pendingEvent: Element?
    private var debounceTask: Task<Void, Never>?
    private let debounceMs: Int

    init(debounceMs: Int = 0) {
        self.debounceMs = max(0, debounceMs)

        var capturedContinuation: AsyncThrowingStream<Element, Error>.Continuation?
        self.events = AsyncThrowingStream<Element, Error> { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    func emit(_ event: Element) {
        guard let continuation else { return }

        if debounceMs == 0 {
            continuation.yield(event)
            return
        }

        pendingEvent = event
        debounceTask?.cancel()
        debounceTask = Task { [debounceMs] in
            try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
            self.flushPendingEvent()
        }
    }

    func finish(throwing error: Error? = nil) {
        debounceTask?.cancel()
        debounceTask = nil
        pendingEvent = nil
        continuation?.finish(throwing: error)
        continuation = nil
    }

    private func flushPendingEvent() {
        guard let event = pendingEvent else { return }
        pendingEvent = nil
        continuation?.yield(event)
    }
}

// MARK: - BLE Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct BLEClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> BLEContext
    typealias PowerOnTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias RadioReadyTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias DeviceDiscoveredDeviceBLEDeviceTransition = @Sendable (BLEContext, BLEDevice) async throws -> BLEContext
    typealias ScanTimeoutTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias ConnectionEstablishedTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias ConnectionFailedReasonStringTransition = @Sendable (BLEContext, String) async throws -> BLEContext
    typealias RetryTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias RetriesExhaustedTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias StartSyncPayloadScalePayloadTransition = @Sendable (BLEContext, ScalePayload) async throws -> BLEContext
    typealias SyncSucceededTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias SyncFailedReasonStringTransition = @Sendable (BLEContext, String) async throws -> BLEContext
    typealias PeripheralDisconnectedTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias ResetRadioTransition = @Sendable (BLEContext) async throws -> BLEContext
    typealias PowerDownTransition = @Sendable (BLEContext) async throws -> BLEContext
    let initialContext: InitialContextBuilder
    let powerOnTransition: PowerOnTransition
    let radioReadyTransition: RadioReadyTransition
    let deviceDiscoveredDeviceBLEDeviceTransition: DeviceDiscoveredDeviceBLEDeviceTransition
    let scanTimeoutTransition: ScanTimeoutTransition
    let connectionEstablishedTransition: ConnectionEstablishedTransition
    let connectionFailedReasonStringTransition: ConnectionFailedReasonStringTransition
    let retryTransition: RetryTransition
    let retriesExhaustedTransition: RetriesExhaustedTransition
    let startSyncPayloadScalePayloadTransition: StartSyncPayloadScalePayloadTransition
    let syncSucceededTransition: SyncSucceededTransition
    let syncFailedReasonStringTransition: SyncFailedReasonStringTransition
    let peripheralDisconnectedTransition: PeripheralDisconnectedTransition
    let resetRadioTransition: ResetRadioTransition
    let powerDownTransition: PowerDownTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        powerOnTransition: @escaping PowerOnTransition,
        radioReadyTransition: @escaping RadioReadyTransition,
        deviceDiscoveredDeviceBLEDeviceTransition: @escaping DeviceDiscoveredDeviceBLEDeviceTransition,
        scanTimeoutTransition: @escaping ScanTimeoutTransition,
        connectionEstablishedTransition: @escaping ConnectionEstablishedTransition,
        connectionFailedReasonStringTransition: @escaping ConnectionFailedReasonStringTransition,
        retryTransition: @escaping RetryTransition,
        retriesExhaustedTransition: @escaping RetriesExhaustedTransition,
        startSyncPayloadScalePayloadTransition: @escaping StartSyncPayloadScalePayloadTransition,
        syncSucceededTransition: @escaping SyncSucceededTransition,
        syncFailedReasonStringTransition: @escaping SyncFailedReasonStringTransition,
        peripheralDisconnectedTransition: @escaping PeripheralDisconnectedTransition,
        resetRadioTransition: @escaping ResetRadioTransition,
        powerDownTransition: @escaping PowerDownTransition
    ) {
        self.initialContext = initialContext
        self.powerOnTransition = powerOnTransition
        self.radioReadyTransition = radioReadyTransition
        self.deviceDiscoveredDeviceBLEDeviceTransition = deviceDiscoveredDeviceBLEDeviceTransition
        self.scanTimeoutTransition = scanTimeoutTransition
        self.connectionEstablishedTransition = connectionEstablishedTransition
        self.connectionFailedReasonStringTransition = connectionFailedReasonStringTransition
        self.retryTransition = retryTransition
        self.retriesExhaustedTransition = retriesExhaustedTransition
        self.startSyncPayloadScalePayloadTransition = startSyncPayloadScalePayloadTransition
        self.syncSucceededTransition = syncSucceededTransition
        self.syncFailedReasonStringTransition = syncFailedReasonStringTransition
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
                return BLEObserver<BLEMachine.Off>(
                    internalContext: context,
                _powerOn: runtime.powerOnTransition,
                _radioReady: runtime.radioReadyTransition,
                _deviceDiscoveredDeviceBLEDevice: runtime.deviceDiscoveredDeviceBLEDeviceTransition,
                _scanTimeout: runtime.scanTimeoutTransition,
                _connectionEstablished: runtime.connectionEstablishedTransition,
                _connectionFailedReasonString: runtime.connectionFailedReasonStringTransition,
                _retry: runtime.retryTransition,
                _retriesExhausted: runtime.retriesExhaustedTransition,
                _startSyncPayloadScalePayload: runtime.startSyncPayloadScalePayloadTransition,
                _syncSucceeded: runtime.syncSucceededTransition,
                _syncFailedReasonString: runtime.syncFailedReasonStringTransition,
                _peripheralDisconnected: runtime.peripheralDisconnectedTransition,
                _resetRadio: runtime.resetRadioTransition,
                _powerDown: runtime.powerDownTransition
                )
            }
        )
    }
}

// MARK: - BLE.Off Transitions

extension BLEObserver where State == BLEMachine.Off {
    /// Handles the `powerOn` transition from Off to WakingRadio.
    public consuming func powerOn() async throws -> BLEObserver<BLEMachine.WakingRadio> {
        let nextContext = try await self._powerOn(self.internalContext)
        return BLEObserver<BLEMachine.WakingRadio>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.WakingRadio Transitions

extension BLEObserver where State == BLEMachine.WakingRadio {
    /// Handles the `radioReady` transition from WakingRadio to Scanning.
    public consuming func radioReady() async throws -> BLEObserver<BLEMachine.Scanning> {
        let nextContext = try await self._radioReady(self.internalContext)
        return BLEObserver<BLEMachine.Scanning>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Scanning Transitions

extension BLEObserver where State == BLEMachine.Scanning {
    /// Handles the `deviceDiscovered` transition from Scanning to Connecting.
    public consuming func deviceDiscovered(device: BLEDevice) async throws -> BLEObserver<BLEMachine.Connecting> {
        let nextContext = try await self._deviceDiscoveredDeviceBLEDevice(self.internalContext, device)
        return BLEObserver<BLEMachine.Connecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `scanTimeout` transition from Scanning to Error.
    public consuming func scanTimeout() async throws -> BLEObserver<BLEMachine.Error> {
        let nextContext = try await self._scanTimeout(self.internalContext)
        return BLEObserver<BLEMachine.Error>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Connecting Transitions

extension BLEObserver where State == BLEMachine.Connecting {
    /// Handles the `connectionEstablished` transition from Connecting to Connected.
    public consuming func connectionEstablished() async throws -> BLEObserver<BLEMachine.Connected> {
        let nextContext = try await self._connectionEstablished(self.internalContext)
        return BLEObserver<BLEMachine.Connected>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `connectionFailed` transition from Connecting to Reconnecting.
    public consuming func connectionFailed(reason: String) async throws -> BLEObserver<BLEMachine.Reconnecting> {
        let nextContext = try await self._connectionFailedReasonString(self.internalContext, reason)
        return BLEObserver<BLEMachine.Reconnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Reconnecting Transitions

extension BLEObserver where State == BLEMachine.Reconnecting {
    /// Handles the `retry` transition from Reconnecting to Connecting.
    public consuming func retry() async throws -> BLEObserver<BLEMachine.Connecting> {
        let nextContext = try await self._retry(self.internalContext)
        return BLEObserver<BLEMachine.Connecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `retriesExhausted` transition from Reconnecting to Error.
    public consuming func retriesExhausted() async throws -> BLEObserver<BLEMachine.Error> {
        let nextContext = try await self._retriesExhausted(self.internalContext)
        return BLEObserver<BLEMachine.Error>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Reconnecting to PoweredDown.
    public consuming func powerDown() async throws -> BLEObserver<BLEMachine.PoweredDown> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEObserver<BLEMachine.PoweredDown>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Connected Transitions

extension BLEObserver where State == BLEMachine.Connected {
    /// Handles the `startSync` transition from Connected to Syncing.
    public consuming func startSync(payload: ScalePayload) async throws -> BLEObserver<BLEMachine.Syncing> {
        let nextContext = try await self._startSyncPayloadScalePayload(self.internalContext, payload)
        return BLEObserver<BLEMachine.Syncing>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `peripheralDisconnected` transition from Connected to Reconnecting.
    public consuming func peripheralDisconnected() async throws -> BLEObserver<BLEMachine.Reconnecting> {
        let nextContext = try await self._peripheralDisconnected(self.internalContext)
        return BLEObserver<BLEMachine.Reconnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Connected to PoweredDown.
    public consuming func powerDown() async throws -> BLEObserver<BLEMachine.PoweredDown> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEObserver<BLEMachine.PoweredDown>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Syncing Transitions

extension BLEObserver where State == BLEMachine.Syncing {
    /// Handles the `syncSucceeded` transition from Syncing to Connected.
    public consuming func syncSucceeded() async throws -> BLEObserver<BLEMachine.Connected> {
        let nextContext = try await self._syncSucceeded(self.internalContext)
        return BLEObserver<BLEMachine.Connected>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `syncFailed` transition from Syncing to Reconnecting.
    public consuming func syncFailed(reason: String) async throws -> BLEObserver<BLEMachine.Reconnecting> {
        let nextContext = try await self._syncFailedReasonString(self.internalContext, reason)
        return BLEObserver<BLEMachine.Reconnecting>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE.Error Transitions

extension BLEObserver where State == BLEMachine.Error {
    /// Handles the `resetRadio` transition from Error to Off.
    public consuming func resetRadio() async throws -> BLEObserver<BLEMachine.Off> {
        let nextContext = try await self._resetRadio(self.internalContext)
        return BLEObserver<BLEMachine.Off>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }

    /// Handles the `powerDown` transition from Error to PoweredDown.
    public consuming func powerDown() async throws -> BLEObserver<BLEMachine.PoweredDown> {
        let nextContext = try await self._powerDown(self.internalContext)
        return BLEObserver<BLEMachine.PoweredDown>(
            internalContext: nextContext,
                _powerOn: self._powerOn,
                _radioReady: self._radioReady,
                _deviceDiscoveredDeviceBLEDevice: self._deviceDiscoveredDeviceBLEDevice,
                _scanTimeout: self._scanTimeout,
                _connectionEstablished: self._connectionEstablished,
                _connectionFailedReasonString: self._connectionFailedReasonString,
                _retry: self._retry,
                _retriesExhausted: self._retriesExhausted,
                _startSyncPayloadScalePayload: self._startSyncPayloadScalePayload,
                _syncSucceeded: self._syncSucceeded,
                _syncFailedReasonString: self._syncFailedReasonString,
                _peripheralDisconnected: self._peripheralDisconnected,
                _resetRadio: self._resetRadio,
                _powerDown: self._powerDown
        )
    }
}

// MARK: - BLE Combined State

/// A runtime-friendly wrapper over all observer states.
public enum BLEState: ~Copyable {
    case off(BLEObserver<BLEMachine.Off>)
    case wakingRadio(BLEObserver<BLEMachine.WakingRadio>)
    case scanning(BLEObserver<BLEMachine.Scanning>)
    case connecting(BLEObserver<BLEMachine.Connecting>)
    case connected(BLEObserver<BLEMachine.Connected>)
    case reconnecting(BLEObserver<BLEMachine.Reconnecting>)
    case syncing(BLEObserver<BLEMachine.Syncing>)
    case error(BLEObserver<BLEMachine.Error>)
    case poweredDown(BLEObserver<BLEMachine.PoweredDown>)

    public init(_ observer: consuming BLEObserver<BLEMachine.Off>) {
        self = .off(observer)
    }
}

extension BLEState {
    public borrowing func withOff<R>(_ body: (borrowing BLEObserver<BLEMachine.Off>) throws -> R) rethrows -> R? {
        switch self {
        case let .off(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withWakingRadio<R>(_ body: (borrowing BLEObserver<BLEMachine.WakingRadio>) throws -> R) rethrows -> R? {
        switch self {
        case let .wakingRadio(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withScanning<R>(_ body: (borrowing BLEObserver<BLEMachine.Scanning>) throws -> R) rethrows -> R? {
        switch self {
        case let .scanning(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withConnecting<R>(_ body: (borrowing BLEObserver<BLEMachine.Connecting>) throws -> R) rethrows -> R? {
        switch self {
        case let .connecting(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withConnected<R>(_ body: (borrowing BLEObserver<BLEMachine.Connected>) throws -> R) rethrows -> R? {
        switch self {
        case let .connected(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withReconnecting<R>(_ body: (borrowing BLEObserver<BLEMachine.Reconnecting>) throws -> R) rethrows -> R? {
        switch self {
        case let .reconnecting(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withSyncing<R>(_ body: (borrowing BLEObserver<BLEMachine.Syncing>) throws -> R) rethrows -> R? {
        switch self {
        case let .syncing(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withError<R>(_ body: (borrowing BLEObserver<BLEMachine.Error>) throws -> R) rethrows -> R? {
        switch self {
        case let .error(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withPoweredDown<R>(_ body: (borrowing BLEObserver<BLEMachine.PoweredDown>) throws -> R) rethrows -> R? {
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
        let next = try await observer.powerOn()
        return .wakingRadio(next)
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
        let next = try await observer.radioReady()
        return .scanning(next)
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
        let next = try await observer.deviceDiscovered(device: device)
        return .connecting(next)
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
        let next = try await observer.scanTimeout()
        return .error(next)
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
        let next = try await observer.connectionEstablished()
        return .connected(next)
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
        let next = try await observer.connectionFailed(reason: reason)
        return .reconnecting(next)
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
        let next = try await observer.retry()
        return .connecting(next)
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
        let next = try await observer.retriesExhausted()
        return .error(next)
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
        let next = try await observer.startSync(payload: payload)
        return .syncing(next)
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
        let next = try await observer.syncSucceeded()
        return .connected(next)
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
        let next = try await observer.syncFailed(reason: reason)
        return .reconnecting(next)
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
        let next = try await observer.peripheralDisconnected()
        return .reconnecting(next)
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
        let next = try await observer.resetRadio()
        return .off(next)
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
        let next = try await observer.powerDown()
        return .poweredDown(next)
    case let .reconnecting(observer):
        let next = try await observer.powerDown()
        return .poweredDown(next)
    case let .syncing(observer):
        return .syncing(observer)
    case let .error(observer):
        let next = try await observer.powerDown()
        return .poweredDown(next)
    case let .poweredDown(observer):
        return .poweredDown(observer)
        }
    }
}

// MARK: - BLE Client

/// Dependency client entry point for constructing BLE observers.
public struct BLEClient: Sendable {
    public var makeBLE: @Sendable () -> BLEObserver<BLEMachine.Off>

    public init(makeBLE: @escaping @Sendable () -> BLEObserver<BLEMachine.Off>) {
        self.makeBLE = makeBLE
    }
}

extension BLEClient: DependencyKey {
    public static let testValue = Self(
        makeBLE: {
                    fatalError("Configure BLEClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeBLE: {
                    fatalError("Configure BLEClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated BLEClient dependency.
    public var bLE: BLEClient {
        get { self[BLEClient.self] }
        set { self[BLEClient.self] = newValue }
    }
}
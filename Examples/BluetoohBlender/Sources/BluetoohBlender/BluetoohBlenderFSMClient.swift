import CoreBluetooth
import Dependencies

// MARK: - BluetoohBlender State Machine

/// Typestate markers for the `BluetoohBlender` machine.
public enum BluetoohBlenderMachine {
    public enum Disconnected {}
    public enum Scanning {}
    public enum Connecting {}
    public enum ConnectedWithBowl {}
    public enum ConnectedWithoutBowl {}
    public enum BlendSlow {}
    public enum BlendMedium {}
    public enum BlendHigh {}
    public enum Paused {}
    public enum Error {}
    public enum TurnedOff {}
    public struct RuntimeContext: Sendable {
        public init() {}
    }
}

// MARK: - BluetoohBlender Runtime Context Bridge

/// Internal state-aware context wrapper used by generated runtime helpers.
struct BluetoohBlenderRuntimeContext: Sendable {
    enum Storage: Sendable {
        case disconnected(BluetoohBlenderMachine.RuntimeContext)
        case scanning(BluetoohBlenderMachine.RuntimeContext)
        case connecting(BluetoohBlenderMachine.RuntimeContext)
        case connectedWithBowl(BluetoohBlenderMachine.RuntimeContext)
        case connectedWithoutBowl(BluetoohBlenderMachine.RuntimeContext)
        case blendSlow(BluetoohBlenderMachine.RuntimeContext)
        case blendMedium(BluetoohBlenderMachine.RuntimeContext)
        case blendHigh(BluetoohBlenderMachine.RuntimeContext)
        case paused(BluetoohBlenderMachine.RuntimeContext)
        case error(BluetoohBlenderMachine.RuntimeContext)
        case turnedOff(BluetoohBlenderMachine.RuntimeContext)
    }

    let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

static func disconnected(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .disconnected(value))
}

static func scanning(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .scanning(value))
}

static func connecting(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .connecting(value))
}

static func connectedWithBowl(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .connectedWithBowl(value))
}

static func connectedWithoutBowl(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .connectedWithoutBowl(value))
}

static func blendSlow(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .blendSlow(value))
}

static func blendMedium(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .blendMedium(value))
}

static func blendHigh(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .blendHigh(value))
}

static func paused(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .paused(value))
}

static func error(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .error(value))
}

static func turnedOff(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .turnedOff(value))
}
}

// MARK: - BluetoohBlender Observer

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct BluetoohBlenderObserver<State>: ~Copyable {
    private var internalContext: BluetoohBlenderMachine.RuntimeContext

    private let _startScan: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _stopScan: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _deviceFoundDeviceCBPeripheral: @Sendable (BluetoohBlenderMachine.RuntimeContext, CBPeripheral) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _timeout: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _cancelConnect: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _connectSuccess: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _connectFailErrorError: @Sendable (BluetoohBlenderMachine.RuntimeContext, Error) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _startBlendSlow: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _startBlendMedium: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _startBlendHigh: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _changeSpeedMedium: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _changeSpeedHigh: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _changeSpeedSlow: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _pauseBlend: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _resumeBlendSlow: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _resumeBlendMedium: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _resumeBlendHigh: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _stopBlend: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _removeBowl: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _switchOff: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _addBowl: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _disconnect: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext

    public init(
        internalContext: BluetoohBlenderMachine.RuntimeContext,
        _startScan: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _stopScan: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _deviceFoundDeviceCBPeripheral: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext, CBPeripheral) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _timeout: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _cancelConnect: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _connectSuccess: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _connectFailErrorError: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext, Error) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _startBlendSlow: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _startBlendMedium: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _startBlendHigh: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _changeSpeedMedium: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _changeSpeedHigh: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _changeSpeedSlow: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _pauseBlend: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _resumeBlendSlow: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _resumeBlendMedium: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _resumeBlendHigh: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _stopBlend: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _removeBowl: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _switchOff: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _addBowl: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _disconnect: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    ) {
        self.internalContext = internalContext

        self._startScan = _startScan
        self._stopScan = _stopScan
        self._deviceFoundDeviceCBPeripheral = _deviceFoundDeviceCBPeripheral
        self._timeout = _timeout
        self._cancelConnect = _cancelConnect
        self._connectSuccess = _connectSuccess
        self._connectFailErrorError = _connectFailErrorError
        self._startBlendSlow = _startBlendSlow
        self._startBlendMedium = _startBlendMedium
        self._startBlendHigh = _startBlendHigh
        self._changeSpeedMedium = _changeSpeedMedium
        self._changeSpeedHigh = _changeSpeedHigh
        self._changeSpeedSlow = _changeSpeedSlow
        self._pauseBlend = _pauseBlend
        self._resumeBlendSlow = _resumeBlendSlow
        self._resumeBlendMedium = _resumeBlendMedium
        self._resumeBlendHigh = _resumeBlendHigh
        self._stopBlend = _stopBlend
        self._removeBowl = _removeBowl
        self._switchOff = _switchOff
        self._addBowl = _addBowl
        self._disconnect = _disconnect
    }

    /// Access the internal context while preserving borrowing semantics.
    public borrowing func withInternalContext<R>(_ body: (borrowing BluetoohBlenderMachine.RuntimeContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - BluetoohBlender Runtime Stream

/// Generic stream lifecycle helper for event-driven runtimes generated from this machine.
actor BluetoohBlenderRuntimeStream<Element: Sendable> {
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

// MARK: - BluetoohBlender Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct BluetoohBlenderClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> BluetoohBlenderMachine.RuntimeContext
    typealias StartScanTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias StopScanTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias DeviceFoundDeviceCBPeripheralTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext, CBPeripheral) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias TimeoutTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias CancelConnectTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ConnectSuccessTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ConnectFailErrorErrorTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext, Error) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias StartBlendSlowTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias StartBlendMediumTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias StartBlendHighTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ChangeSpeedMediumTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ChangeSpeedHighTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ChangeSpeedSlowTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias PauseBlendTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ResumeBlendSlowTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ResumeBlendMediumTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ResumeBlendHighTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias StopBlendTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias RemoveBowlTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias SwitchOffTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias AddBowlTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias DisconnectTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    let initialContext: InitialContextBuilder
    let startScanTransition: StartScanTransition
    let stopScanTransition: StopScanTransition
    let deviceFoundDeviceCBPeripheralTransition: DeviceFoundDeviceCBPeripheralTransition
    let timeoutTransition: TimeoutTransition
    let cancelConnectTransition: CancelConnectTransition
    let connectSuccessTransition: ConnectSuccessTransition
    let connectFailErrorErrorTransition: ConnectFailErrorErrorTransition
    let startBlendSlowTransition: StartBlendSlowTransition
    let startBlendMediumTransition: StartBlendMediumTransition
    let startBlendHighTransition: StartBlendHighTransition
    let changeSpeedMediumTransition: ChangeSpeedMediumTransition
    let changeSpeedHighTransition: ChangeSpeedHighTransition
    let changeSpeedSlowTransition: ChangeSpeedSlowTransition
    let pauseBlendTransition: PauseBlendTransition
    let resumeBlendSlowTransition: ResumeBlendSlowTransition
    let resumeBlendMediumTransition: ResumeBlendMediumTransition
    let resumeBlendHighTransition: ResumeBlendHighTransition
    let stopBlendTransition: StopBlendTransition
    let removeBowlTransition: RemoveBowlTransition
    let switchOffTransition: SwitchOffTransition
    let addBowlTransition: AddBowlTransition
    let disconnectTransition: DisconnectTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        startScanTransition: @escaping StartScanTransition,
        stopScanTransition: @escaping StopScanTransition,
        deviceFoundDeviceCBPeripheralTransition: @escaping DeviceFoundDeviceCBPeripheralTransition,
        timeoutTransition: @escaping TimeoutTransition,
        cancelConnectTransition: @escaping CancelConnectTransition,
        connectSuccessTransition: @escaping ConnectSuccessTransition,
        connectFailErrorErrorTransition: @escaping ConnectFailErrorErrorTransition,
        startBlendSlowTransition: @escaping StartBlendSlowTransition,
        startBlendMediumTransition: @escaping StartBlendMediumTransition,
        startBlendHighTransition: @escaping StartBlendHighTransition,
        changeSpeedMediumTransition: @escaping ChangeSpeedMediumTransition,
        changeSpeedHighTransition: @escaping ChangeSpeedHighTransition,
        changeSpeedSlowTransition: @escaping ChangeSpeedSlowTransition,
        pauseBlendTransition: @escaping PauseBlendTransition,
        resumeBlendSlowTransition: @escaping ResumeBlendSlowTransition,
        resumeBlendMediumTransition: @escaping ResumeBlendMediumTransition,
        resumeBlendHighTransition: @escaping ResumeBlendHighTransition,
        stopBlendTransition: @escaping StopBlendTransition,
        removeBowlTransition: @escaping RemoveBowlTransition,
        switchOffTransition: @escaping SwitchOffTransition,
        addBowlTransition: @escaping AddBowlTransition,
        disconnectTransition: @escaping DisconnectTransition
    ) {
        self.initialContext = initialContext
        self.startScanTransition = startScanTransition
        self.stopScanTransition = stopScanTransition
        self.deviceFoundDeviceCBPeripheralTransition = deviceFoundDeviceCBPeripheralTransition
        self.timeoutTransition = timeoutTransition
        self.cancelConnectTransition = cancelConnectTransition
        self.connectSuccessTransition = connectSuccessTransition
        self.connectFailErrorErrorTransition = connectFailErrorErrorTransition
        self.startBlendSlowTransition = startBlendSlowTransition
        self.startBlendMediumTransition = startBlendMediumTransition
        self.startBlendHighTransition = startBlendHighTransition
        self.changeSpeedMediumTransition = changeSpeedMediumTransition
        self.changeSpeedHighTransition = changeSpeedHighTransition
        self.changeSpeedSlowTransition = changeSpeedSlowTransition
        self.pauseBlendTransition = pauseBlendTransition
        self.resumeBlendSlowTransition = resumeBlendSlowTransition
        self.resumeBlendMediumTransition = resumeBlendMediumTransition
        self.resumeBlendHighTransition = resumeBlendHighTransition
        self.stopBlendTransition = stopBlendTransition
        self.removeBowlTransition = removeBowlTransition
        self.switchOffTransition = switchOffTransition
        self.addBowlTransition = addBowlTransition
        self.disconnectTransition = disconnectTransition
    }
}

extension BluetoohBlenderClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: BluetoohBlenderClientRuntime) -> Self {
        Self(
            makeBlender: {
                let context = runtime.initialContext()
                return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
                    internalContext: context,
                _startScan: runtime.startScanTransition,
                _stopScan: runtime.stopScanTransition,
                _deviceFoundDeviceCBPeripheral: runtime.deviceFoundDeviceCBPeripheralTransition,
                _timeout: runtime.timeoutTransition,
                _cancelConnect: runtime.cancelConnectTransition,
                _connectSuccess: runtime.connectSuccessTransition,
                _connectFailErrorError: runtime.connectFailErrorErrorTransition,
                _startBlendSlow: runtime.startBlendSlowTransition,
                _startBlendMedium: runtime.startBlendMediumTransition,
                _startBlendHigh: runtime.startBlendHighTransition,
                _changeSpeedMedium: runtime.changeSpeedMediumTransition,
                _changeSpeedHigh: runtime.changeSpeedHighTransition,
                _changeSpeedSlow: runtime.changeSpeedSlowTransition,
                _pauseBlend: runtime.pauseBlendTransition,
                _resumeBlendSlow: runtime.resumeBlendSlowTransition,
                _resumeBlendMedium: runtime.resumeBlendMediumTransition,
                _resumeBlendHigh: runtime.resumeBlendHighTransition,
                _stopBlend: runtime.stopBlendTransition,
                _removeBowl: runtime.removeBowlTransition,
                _switchOff: runtime.switchOffTransition,
                _addBowl: runtime.addBowlTransition,
                _disconnect: runtime.disconnectTransition
                )
            }
        )
    }
}

// MARK: - BluetoohBlender.Disconnected Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Disconnected {
    /// Handles the `startScan` transition from Disconnected to Scanning.
    public consuming func startScan() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Scanning> {
        let nextContext = try await self._startScan(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Scanning>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Scanning Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Scanning {
    /// Handles the `stopScan` transition from Scanning to Disconnected.
    public consuming func stopScan() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected> {
        let nextContext = try await self._stopScan(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `deviceFound` transition from Scanning to Connecting.
    public consuming func deviceFound(device: CBPeripheral) async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Connecting> {
        let nextContext = try await self._deviceFoundDeviceCBPeripheral(self.internalContext, device)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Connecting>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `timeout` transition from Scanning to Disconnected.
    public consuming func timeout() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected> {
        let nextContext = try await self._timeout(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Connecting Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Connecting {
    /// Handles the `cancelConnect` transition from Connecting to Disconnected.
    public consuming func cancelConnect() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected> {
        let nextContext = try await self._cancelConnect(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `connectSuccess` transition from Connecting to ConnectedWithBowl.
    public consuming func connectSuccess() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl> {
        let nextContext = try await self._connectSuccess(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `connectFail` transition from Connecting to Error.
    public consuming func connectFail(error: Error) async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Error> {
        let nextContext = try await self._connectFailErrorError(self.internalContext, error)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Error>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.ConnectedWithBowl Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.ConnectedWithBowl {
    /// Handles the `startBlendSlow` transition from ConnectedWithBowl to BlendSlow.
    public consuming func startBlendSlow() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow> {
        let nextContext = try await self._startBlendSlow(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `startBlendMedium` transition from ConnectedWithBowl to BlendMedium.
    public consuming func startBlendMedium() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium> {
        let nextContext = try await self._startBlendMedium(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `startBlendHigh` transition from ConnectedWithBowl to BlendHigh.
    public consuming func startBlendHigh() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh> {
        let nextContext = try await self._startBlendHigh(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `removeBowl` transition from ConnectedWithBowl to ConnectedWithoutBowl.
    public consuming func removeBowl() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithoutBowl> {
        let nextContext = try await self._removeBowl(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithoutBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `switchOff` transition from ConnectedWithBowl to TurnedOff.
    public consuming func switchOff() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff> {
        let nextContext = try await self._switchOff(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `disconnect` transition from ConnectedWithBowl to Disconnected.
    public consuming func disconnect() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected> {
        let nextContext = try await self._disconnect(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.BlendSlow Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.BlendSlow {
    /// Handles the `changeSpeedMedium` transition from BlendSlow to BlendMedium.
    public consuming func changeSpeedMedium() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium> {
        let nextContext = try await self._changeSpeedMedium(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `changeSpeedHigh` transition from BlendSlow to BlendHigh.
    public consuming func changeSpeedHigh() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh> {
        let nextContext = try await self._changeSpeedHigh(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `pauseBlend` transition from BlendSlow to Paused.
    public consuming func pauseBlend() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Paused> {
        let nextContext = try await self._pauseBlend(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Paused>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from BlendSlow to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.BlendMedium Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.BlendMedium {
    /// Handles the `changeSpeedSlow` transition from BlendMedium to BlendSlow.
    public consuming func changeSpeedSlow() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow> {
        let nextContext = try await self._changeSpeedSlow(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `changeSpeedHigh` transition from BlendMedium to BlendHigh.
    public consuming func changeSpeedHigh() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh> {
        let nextContext = try await self._changeSpeedHigh(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `pauseBlend` transition from BlendMedium to Paused.
    public consuming func pauseBlend() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Paused> {
        let nextContext = try await self._pauseBlend(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Paused>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from BlendMedium to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.BlendHigh Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.BlendHigh {
    /// Handles the `changeSpeedSlow` transition from BlendHigh to BlendSlow.
    public consuming func changeSpeedSlow() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow> {
        let nextContext = try await self._changeSpeedSlow(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `changeSpeedMedium` transition from BlendHigh to BlendMedium.
    public consuming func changeSpeedMedium() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium> {
        let nextContext = try await self._changeSpeedMedium(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `pauseBlend` transition from BlendHigh to Paused.
    public consuming func pauseBlend() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Paused> {
        let nextContext = try await self._pauseBlend(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Paused>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from BlendHigh to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Paused Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Paused {
    /// Handles the `resumeBlendSlow` transition from Paused to BlendSlow.
    public consuming func resumeBlendSlow() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow> {
        let nextContext = try await self._resumeBlendSlow(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `resumeBlendMedium` transition from Paused to BlendMedium.
    public consuming func resumeBlendMedium() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium> {
        let nextContext = try await self._resumeBlendMedium(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `resumeBlendHigh` transition from Paused to BlendHigh.
    public consuming func resumeBlendHigh() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh> {
        let nextContext = try await self._resumeBlendHigh(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from Paused to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.ConnectedWithoutBowl Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.ConnectedWithoutBowl {
    /// Handles the `addBowl` transition from ConnectedWithoutBowl to ConnectedWithBowl.
    public consuming func addBowl() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl> {
        let nextContext = try await self._addBowl(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `disconnect` transition from ConnectedWithoutBowl to Disconnected.
    public consuming func disconnect() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected> {
        let nextContext = try await self._disconnect(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `switchOff` transition from ConnectedWithoutBowl to TurnedOff.
    public consuming func switchOff() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff> {
        let nextContext = try await self._switchOff(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Error Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Error {
    /// Handles the `switchOff` transition from Error to TurnedOff.
    public consuming func switchOff() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff> {
        let nextContext = try await self._switchOff(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender Combined State

/// A runtime-friendly wrapper over all observer states.
public enum BluetoohBlenderState: ~Copyable {
    case disconnected(BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>)
    case scanning(BluetoohBlenderObserver<BluetoohBlenderMachine.Scanning>)
    case connecting(BluetoohBlenderObserver<BluetoohBlenderMachine.Connecting>)
    case connectedWithBowl(BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>)
    case connectedWithoutBowl(BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithoutBowl>)
    case blendSlow(BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow>)
    case blendMedium(BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium>)
    case blendHigh(BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh>)
    case paused(BluetoohBlenderObserver<BluetoohBlenderMachine.Paused>)
    case error(BluetoohBlenderObserver<BluetoohBlenderMachine.Error>)
    case turnedOff(BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff>)

    public init(_ observer: consuming BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>) {
        self = .disconnected(observer)
    }
}

extension BluetoohBlenderState {
    public borrowing func withDisconnected<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>) throws -> R) rethrows -> R? {
        switch self {
        case let .disconnected(observer):
            return try body(observer)

        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withScanning<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.Scanning>) throws -> R) rethrows -> R? {
        switch self {
        case let .scanning(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withConnecting<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.Connecting>) throws -> R) rethrows -> R? {
        switch self {
        case let .connecting(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withConnectedWithBowl<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl>) throws -> R) rethrows -> R? {
        switch self {
        case let .connectedWithBowl(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withConnectedWithoutBowl<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithoutBowl>) throws -> R) rethrows -> R? {
        switch self {
        case let .connectedWithoutBowl(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withBlendSlow<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.BlendSlow>) throws -> R) rethrows -> R? {
        switch self {
        case let .blendSlow(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withBlendMedium<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.BlendMedium>) throws -> R) rethrows -> R? {
        switch self {
        case let .blendMedium(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withBlendHigh<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.BlendHigh>) throws -> R) rethrows -> R? {
        switch self {
        case let .blendHigh(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withPaused<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.Paused>) throws -> R) rethrows -> R? {
        switch self {
        case let .paused(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .error:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withError<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.Error>) throws -> R) rethrows -> R? {
        switch self {
        case let .error(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .turnedOff:
            return nil
        }
    }

    public borrowing func withTurnedOff<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.TurnedOff>) throws -> R) rethrows -> R? {
        switch self {
        case let .turnedOff(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .connectedWithBowl:
            return nil
        case .connectedWithoutBowl:
            return nil
        case .blendSlow:
            return nil
        case .blendMedium:
            return nil
        case .blendHigh:
            return nil
        case .paused:
            return nil
        case .error:
            return nil
        }
    }


    /// Attempts the `startScan` transition from the current wrapper state.
    public consuming func startScan() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        let next = try await observer.startScan()
        return .scanning(next)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `stopScan` transition from the current wrapper state.
    public consuming func stopScan() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        let next = try await observer.stopScan()
        return .disconnected(next)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `deviceFound` transition from the current wrapper state.
    public consuming func deviceFound(device: CBPeripheral) async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        let next = try await observer.deviceFound(device: device)
        return .connecting(next)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `timeout` transition from the current wrapper state.
    public consuming func timeout() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        let next = try await observer.timeout()
        return .disconnected(next)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `cancelConnect` transition from the current wrapper state.
    public consuming func cancelConnect() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        let next = try await observer.cancelConnect()
        return .disconnected(next)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `connectSuccess` transition from the current wrapper state.
    public consuming func connectSuccess() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        let next = try await observer.connectSuccess()
        return .connectedWithBowl(next)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `connectFail` transition from the current wrapper state.
    public consuming func connectFail(error: Error) async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        let next = try await observer.connectFail(error: error)
        return .error(next)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `startBlendSlow` transition from the current wrapper state.
    public consuming func startBlendSlow() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        let next = try await observer.startBlendSlow()
        return .blendSlow(next)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `startBlendMedium` transition from the current wrapper state.
    public consuming func startBlendMedium() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        let next = try await observer.startBlendMedium()
        return .blendMedium(next)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `startBlendHigh` transition from the current wrapper state.
    public consuming func startBlendHigh() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        let next = try await observer.startBlendHigh()
        return .blendHigh(next)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `changeSpeedMedium` transition from the current wrapper state.
    public consuming func changeSpeedMedium() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        let next = try await observer.changeSpeedMedium()
        return .blendMedium(next)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        let next = try await observer.changeSpeedMedium()
        return .blendMedium(next)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `changeSpeedHigh` transition from the current wrapper state.
    public consuming func changeSpeedHigh() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        let next = try await observer.changeSpeedHigh()
        return .blendHigh(next)
    case let .blendMedium(observer):
        let next = try await observer.changeSpeedHigh()
        return .blendHigh(next)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `changeSpeedSlow` transition from the current wrapper state.
    public consuming func changeSpeedSlow() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        let next = try await observer.changeSpeedSlow()
        return .blendSlow(next)
    case let .blendHigh(observer):
        let next = try await observer.changeSpeedSlow()
        return .blendSlow(next)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `pauseBlend` transition from the current wrapper state.
    public consuming func pauseBlend() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        let next = try await observer.pauseBlend()
        return .paused(next)
    case let .blendMedium(observer):
        let next = try await observer.pauseBlend()
        return .paused(next)
    case let .blendHigh(observer):
        let next = try await observer.pauseBlend()
        return .paused(next)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `resumeBlendSlow` transition from the current wrapper state.
    public consuming func resumeBlendSlow() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        let next = try await observer.resumeBlendSlow()
        return .blendSlow(next)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `resumeBlendMedium` transition from the current wrapper state.
    public consuming func resumeBlendMedium() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        let next = try await observer.resumeBlendMedium()
        return .blendMedium(next)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `resumeBlendHigh` transition from the current wrapper state.
    public consuming func resumeBlendHigh() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        let next = try await observer.resumeBlendHigh()
        return .blendHigh(next)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `stopBlend` transition from the current wrapper state.
    public consuming func stopBlend() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        let next = try await observer.stopBlend()
        return .connectedWithBowl(next)
    case let .blendMedium(observer):
        let next = try await observer.stopBlend()
        return .connectedWithBowl(next)
    case let .blendHigh(observer):
        let next = try await observer.stopBlend()
        return .connectedWithBowl(next)
    case let .paused(observer):
        let next = try await observer.stopBlend()
        return .connectedWithBowl(next)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `removeBowl` transition from the current wrapper state.
    public consuming func removeBowl() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        let next = try await observer.removeBowl()
        return .connectedWithoutBowl(next)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `switchOff` transition from the current wrapper state.
    public consuming func switchOff() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        let next = try await observer.switchOff()
        return .turnedOff(next)
    case let .connectedWithoutBowl(observer):
        let next = try await observer.switchOff()
        return .turnedOff(next)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        let next = try await observer.switchOff()
        return .turnedOff(next)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `addBowl` transition from the current wrapper state.
    public consuming func addBowl() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        let next = try await observer.addBowl()
        return .connectedWithBowl(next)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `disconnect` transition from the current wrapper state.
    public consuming func disconnect() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        let next = try await observer.disconnect()
        return .disconnected(next)
    case let .connectedWithoutBowl(observer):
        let next = try await observer.disconnect()
        return .disconnected(next)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }
}

// MARK: - BluetoohBlender Client

/// Dependency client entry point for constructing BluetoohBlender observers.
public struct BluetoohBlenderClient: Sendable {
    public var makeBlender: @Sendable () -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>

    public init(makeBlender: @escaping @Sendable () -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>) {
        self.makeBlender = makeBlender
    }
}

extension BluetoohBlenderClient: DependencyKey {
    public static let testValue = Self(
        makeBlender: {
                    fatalError("Configure BluetoohBlenderClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeBlender: {
                    fatalError("Configure BluetoohBlenderClient.previewValue in previews.")
                }
    )

    public static let liveValue = Self(
        makeBlender: {
                    fatalError("Configure BluetoohBlenderClient.liveValue in your app target.")
                }
    )
}

extension DependencyValues {
    /// Accessor for the generated BluetoohBlenderClient dependency.
    public var bluetoohBlender: BluetoohBlenderClient {
        get { self[BluetoohBlenderClient.self] }
        set { self[BluetoohBlenderClient.self] = newValue }
    }
}
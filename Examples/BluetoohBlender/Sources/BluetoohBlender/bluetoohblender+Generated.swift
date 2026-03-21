import CoreBluetooth
import Dependencies

// MARK: - BluetoohBlender State Machine

/// Typestate markers for the `BluetoohBlender` machine.
public enum BluetoohBlenderMachine {
    public enum Disconnected {}
    public enum Scanning {}
    public enum Connecting {}
    public enum Connected {}
    public enum Error {}
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
        case connected(BluetoohBlenderMachine.RuntimeContext)
        case error(BluetoohBlenderMachine.RuntimeContext)
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

static func connected(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .connected(value))
}

static func error(_ value: BluetoohBlenderMachine.RuntimeContext) -> Self {
    .init(storage: .error(value))
}
}

// MARK: - BluetoohBlender Observer

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct BluetoohBlenderObserver<State>: ~Copyable {
    private var internalContext: BluetoohBlenderMachine.RuntimeContext

    private let _startScan: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _deviceFoundDeviceCBPeripheral: @Sendable (BluetoohBlenderMachine.RuntimeContext, CBPeripheral) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _timeout: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _connectSuccess: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _connectFailErrorError: @Sendable (BluetoohBlenderMachine.RuntimeContext, Error) async throws -> BluetoohBlenderMachine.RuntimeContext
    private let _disconnect: @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext

    public init(
        internalContext: BluetoohBlenderMachine.RuntimeContext,
        _startScan: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _deviceFoundDeviceCBPeripheral: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext, CBPeripheral) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _timeout: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _connectSuccess: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _connectFailErrorError: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext, Error) async throws -> BluetoohBlenderMachine.RuntimeContext,
        _disconnect: @escaping @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    ) {
        self.internalContext = internalContext

        self._startScan = _startScan
        self._deviceFoundDeviceCBPeripheral = _deviceFoundDeviceCBPeripheral
        self._timeout = _timeout
        self._connectSuccess = _connectSuccess
        self._connectFailErrorError = _connectFailErrorError
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
    typealias DeviceFoundDeviceCBPeripheralTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext, CBPeripheral) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias TimeoutTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ConnectSuccessTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias ConnectFailErrorErrorTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext, Error) async throws -> BluetoohBlenderMachine.RuntimeContext
    typealias DisconnectTransition = @Sendable (BluetoohBlenderMachine.RuntimeContext) async throws -> BluetoohBlenderMachine.RuntimeContext
    let initialContext: InitialContextBuilder
    let startScanTransition: StartScanTransition
    let deviceFoundDeviceCBPeripheralTransition: DeviceFoundDeviceCBPeripheralTransition
    let timeoutTransition: TimeoutTransition
    let connectSuccessTransition: ConnectSuccessTransition
    let connectFailErrorErrorTransition: ConnectFailErrorErrorTransition
    let disconnectTransition: DisconnectTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        startScanTransition: @escaping StartScanTransition,
        deviceFoundDeviceCBPeripheralTransition: @escaping DeviceFoundDeviceCBPeripheralTransition,
        timeoutTransition: @escaping TimeoutTransition,
        connectSuccessTransition: @escaping ConnectSuccessTransition,
        connectFailErrorErrorTransition: @escaping ConnectFailErrorErrorTransition,
        disconnectTransition: @escaping DisconnectTransition
    ) {
        self.initialContext = initialContext
        self.startScanTransition = startScanTransition
        self.deviceFoundDeviceCBPeripheralTransition = deviceFoundDeviceCBPeripheralTransition
        self.timeoutTransition = timeoutTransition
        self.connectSuccessTransition = connectSuccessTransition
        self.connectFailErrorErrorTransition = connectFailErrorErrorTransition
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
                _deviceFoundDeviceCBPeripheral: runtime.deviceFoundDeviceCBPeripheralTransition,
                _timeout: runtime.timeoutTransition,
                _connectSuccess: runtime.connectSuccessTransition,
                _connectFailErrorError: runtime.connectFailErrorErrorTransition,
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
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Scanning Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Scanning {
    /// Handles the `deviceFound` transition from Scanning to Connecting.
    public consuming func deviceFound(device: CBPeripheral) async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Connecting> {
        let nextContext = try await self._deviceFoundDeviceCBPeripheral(self.internalContext, device)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Connecting>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `timeout` transition from Scanning to Disconnected.
    public consuming func timeout() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected> {
        let nextContext = try await self._timeout(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Connecting Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Connecting {
    /// Handles the `connectSuccess` transition from Connecting to Connected.
    public consuming func connectSuccess() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Connected> {
        let nextContext = try await self._connectSuccess(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Connected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `connectFail` transition from Connecting to Error.
    public consuming func connectFail(error: Error) async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Error> {
        let nextContext = try await self._connectFailErrorError(self.internalContext, error)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Error>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Connected Transitions

extension BluetoohBlenderObserver where State == BluetoohBlenderMachine.Connected {
    /// Handles the `disconnect` transition from Connected to Disconnected.
    public consuming func disconnect() async throws -> BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected> {
        let nextContext = try await self._disconnect(self.internalContext)
        return BluetoohBlenderObserver<BluetoohBlenderMachine.Disconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _deviceFoundDeviceCBPeripheral: self._deviceFoundDeviceCBPeripheral,
                _timeout: self._timeout,
                _connectSuccess: self._connectSuccess,
                _connectFailErrorError: self._connectFailErrorError,
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
    case connected(BluetoohBlenderObserver<BluetoohBlenderMachine.Connected>)
    case error(BluetoohBlenderObserver<BluetoohBlenderMachine.Error>)

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
        case .connected:
            return nil
        case .error:
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
        case .connected:
            return nil
        case .error:
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
        case .connected:
            return nil
        case .error:
            return nil
        }
    }

    public borrowing func withConnected<R>(_ body: (borrowing BluetoohBlenderObserver<BluetoohBlenderMachine.Connected>) throws -> R) rethrows -> R? {
        switch self {
        case let .connected(observer):
            return try body(observer)

        case .disconnected:
            return nil
        case .scanning:
            return nil
        case .connecting:
            return nil
        case .error:
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
        case .connected:
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
    case let .connected(observer):
        return .connected(observer)
    case let .error(observer):
        return .error(observer)
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
    case let .connected(observer):
        return .connected(observer)
    case let .error(observer):
        return .error(observer)
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
    case let .connected(observer):
        return .connected(observer)
    case let .error(observer):
        return .error(observer)
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
        return .connected(next)
    case let .connected(observer):
        return .connected(observer)
    case let .error(observer):
        return .error(observer)
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
    case let .connected(observer):
        return .connected(observer)
    case let .error(observer):
        return .error(observer)
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
    case let .connected(observer):
        let next = try await observer.disconnect()
        return .disconnected(next)
    case let .error(observer):
        return .error(observer)
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
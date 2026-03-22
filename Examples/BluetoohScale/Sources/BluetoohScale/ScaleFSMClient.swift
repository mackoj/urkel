import Foundation
import Dependencies

// MARK: - Scale State Machine

/// Typestate markers for the `Scale` machine.
public enum ScaleMachine {
    public enum Off {}
    public enum WakingUp {}
    public enum Tare {}
    public enum Weighing {}
    public enum Stabilized {}
    public enum MeasuringImpedance {}
    public enum Syncing {}
    public enum PowerDown {}
}

// MARK: - Scale Runtime Context Bridge

/// Internal state-aware context wrapper used by generated runtime helpers.
struct ScaleRuntimeContext: Sendable {
    enum Storage: Sendable {
        case off(ScaleContext)
        case wakingUp(ScaleContext)
        case tare(ScaleContext)
        case weighing(ScaleContext)
        case stabilized(ScaleContext)
        case measuringImpedance(ScaleContext)
        case syncing(ScaleContext)
        case powerDown(ScaleContext)
    }

    let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

static func off(_ value: ScaleContext) -> Self {
    .init(storage: .off(value))
}

static func wakingUp(_ value: ScaleContext) -> Self {
    .init(storage: .wakingUp(value))
}

static func tare(_ value: ScaleContext) -> Self {
    .init(storage: .tare(value))
}

static func weighing(_ value: ScaleContext) -> Self {
    .init(storage: .weighing(value))
}

static func stabilized(_ value: ScaleContext) -> Self {
    .init(storage: .stabilized(value))
}

static func measuringImpedance(_ value: ScaleContext) -> Self {
    .init(storage: .measuringImpedance(value))
}

static func syncing(_ value: ScaleContext) -> Self {
    .init(storage: .syncing(value))
}

static func powerDown(_ value: ScaleContext) -> Self {
    .init(storage: .powerDown(value))
}
}

// MARK: - Scale Observer

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct ScaleObserver<State>: ~Copyable {
    private var internalContext: ScaleContext

    private let _footTap: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _hardwareReady: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _zeroAchieved: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _weightLockedWeightDouble: @Sendable (ScaleContext, Double) async throws -> ScaleContext
    private let _userSteppedOffEarly: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _startBIA: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _biaCompleteMetricsBodyMetrics: @Sendable (ScaleContext, BodyMetrics) async throws -> ScaleContext
    private let _bareFeetRequiredError: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _syncDataPayloadScalePayload: @Sendable (ScaleContext, ScalePayload) async throws -> ScaleContext
    private let _hardwareFault: @Sendable (ScaleContext) async throws -> ScaleContext

    public init(
        internalContext: ScaleContext,
        _footTap: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _hardwareReady: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _zeroAchieved: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _weightLockedWeightDouble: @escaping @Sendable (ScaleContext, Double) async throws -> ScaleContext,
        _userSteppedOffEarly: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _startBIA: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _biaCompleteMetricsBodyMetrics: @escaping @Sendable (ScaleContext, BodyMetrics) async throws -> ScaleContext,
        _bareFeetRequiredError: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _syncDataPayloadScalePayload: @escaping @Sendable (ScaleContext, ScalePayload) async throws -> ScaleContext,
        _hardwareFault: @escaping @Sendable (ScaleContext) async throws -> ScaleContext
    ) {
        self.internalContext = internalContext

        self._footTap = _footTap
        self._hardwareReady = _hardwareReady
        self._zeroAchieved = _zeroAchieved
        self._weightLockedWeightDouble = _weightLockedWeightDouble
        self._userSteppedOffEarly = _userSteppedOffEarly
        self._startBIA = _startBIA
        self._biaCompleteMetricsBodyMetrics = _biaCompleteMetricsBodyMetrics
        self._bareFeetRequiredError = _bareFeetRequiredError
        self._syncDataPayloadScalePayload = _syncDataPayloadScalePayload
        self._hardwareFault = _hardwareFault
    }

    /// Access the internal context while preserving borrowing semantics.
    public borrowing func withInternalContext<R>(_ body: (borrowing ScaleContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - Scale Runtime Stream

/// Generic stream lifecycle helper for event-driven runtimes generated from this machine.
actor ScaleRuntimeStream<Element: Sendable> {
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

// MARK: - Scale Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct ScaleClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> ScaleContext
    typealias FootTapTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias HardwareReadyTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias ZeroAchievedTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias WeightLockedWeightDoubleTransition = @Sendable (ScaleContext, Double) async throws -> ScaleContext
    typealias UserSteppedOffEarlyTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias StartBIATransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias BiaCompleteMetricsBodyMetricsTransition = @Sendable (ScaleContext, BodyMetrics) async throws -> ScaleContext
    typealias BareFeetRequiredErrorTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias SyncDataPayloadScalePayloadTransition = @Sendable (ScaleContext, ScalePayload) async throws -> ScaleContext
    typealias HardwareFaultTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    let initialContext: InitialContextBuilder
    let footTapTransition: FootTapTransition
    let hardwareReadyTransition: HardwareReadyTransition
    let zeroAchievedTransition: ZeroAchievedTransition
    let weightLockedWeightDoubleTransition: WeightLockedWeightDoubleTransition
    let userSteppedOffEarlyTransition: UserSteppedOffEarlyTransition
    let startBIATransition: StartBIATransition
    let biaCompleteMetricsBodyMetricsTransition: BiaCompleteMetricsBodyMetricsTransition
    let bareFeetRequiredErrorTransition: BareFeetRequiredErrorTransition
    let syncDataPayloadScalePayloadTransition: SyncDataPayloadScalePayloadTransition
    let hardwareFaultTransition: HardwareFaultTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        footTapTransition: @escaping FootTapTransition,
        hardwareReadyTransition: @escaping HardwareReadyTransition,
        zeroAchievedTransition: @escaping ZeroAchievedTransition,
        weightLockedWeightDoubleTransition: @escaping WeightLockedWeightDoubleTransition,
        userSteppedOffEarlyTransition: @escaping UserSteppedOffEarlyTransition,
        startBIATransition: @escaping StartBIATransition,
        biaCompleteMetricsBodyMetricsTransition: @escaping BiaCompleteMetricsBodyMetricsTransition,
        bareFeetRequiredErrorTransition: @escaping BareFeetRequiredErrorTransition,
        syncDataPayloadScalePayloadTransition: @escaping SyncDataPayloadScalePayloadTransition,
        hardwareFaultTransition: @escaping HardwareFaultTransition
    ) {
        self.initialContext = initialContext
        self.footTapTransition = footTapTransition
        self.hardwareReadyTransition = hardwareReadyTransition
        self.zeroAchievedTransition = zeroAchievedTransition
        self.weightLockedWeightDoubleTransition = weightLockedWeightDoubleTransition
        self.userSteppedOffEarlyTransition = userSteppedOffEarlyTransition
        self.startBIATransition = startBIATransition
        self.biaCompleteMetricsBodyMetricsTransition = biaCompleteMetricsBodyMetricsTransition
        self.bareFeetRequiredErrorTransition = bareFeetRequiredErrorTransition
        self.syncDataPayloadScalePayloadTransition = syncDataPayloadScalePayloadTransition
        self.hardwareFaultTransition = hardwareFaultTransition
    }
}

extension ScaleClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: ScaleClientRuntime) -> Self {
        Self(
            makeScale: {
                let context = runtime.initialContext()
                return ScaleObserver<ScaleMachine.Off>(
                    internalContext: context,
                _footTap: runtime.footTapTransition,
                _hardwareReady: runtime.hardwareReadyTransition,
                _zeroAchieved: runtime.zeroAchievedTransition,
                _weightLockedWeightDouble: runtime.weightLockedWeightDoubleTransition,
                _userSteppedOffEarly: runtime.userSteppedOffEarlyTransition,
                _startBIA: runtime.startBIATransition,
                _biaCompleteMetricsBodyMetrics: runtime.biaCompleteMetricsBodyMetricsTransition,
                _bareFeetRequiredError: runtime.bareFeetRequiredErrorTransition,
                _syncDataPayloadScalePayload: runtime.syncDataPayloadScalePayloadTransition,
                _hardwareFault: runtime.hardwareFaultTransition
                )
            }
        )
    }
}

// MARK: - Scale.Off Transitions

extension ScaleObserver where State == ScaleMachine.Off {
    /// Wakes the scale hardware from deep sleep
    public consuming func footTap() async throws -> ScaleObserver<ScaleMachine.WakingUp> {
        let nextContext = try await self._footTap(self.internalContext)
        return ScaleObserver<ScaleMachine.WakingUp>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }
}

// MARK: - Scale.WakingUp Transitions

extension ScaleObserver where State == ScaleMachine.WakingUp {
    /// FORK: Hardware initialized. Move to Tare, and simultaneously spawn the BLE radio machine.
    public consuming func hardwareReady() async throws -> ScaleObserver<ScaleMachine.Tare> {
        let nextContext = try await self._hardwareReady(self.internalContext)
        return ScaleObserver<ScaleMachine.Tare>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }
}

// MARK: - Scale.Tare Transitions

extension ScaleObserver where State == ScaleMachine.Tare {
    /// Calibrates the load cells to zero
    public consuming func zeroAchieved() async throws -> ScaleObserver<ScaleMachine.Weighing> {
        let nextContext = try await self._zeroAchieved(self.internalContext)
        return ScaleObserver<ScaleMachine.Weighing>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }
}

// MARK: - Scale.Weighing Transitions

extension ScaleObserver where State == ScaleMachine.Weighing {
    /// Locks in the physical weight measurement
    public consuming func weightLocked(weight: Double) async throws -> ScaleObserver<ScaleMachine.Stabilized> {
        let nextContext = try await self._weightLockedWeightDouble(self.internalContext, weight)
        return ScaleObserver<ScaleMachine.Stabilized>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }

    /// Graceful exit if the user steps off before a lock is achieved
    public consuming func userSteppedOffEarly() async throws -> ScaleObserver<ScaleMachine.PowerDown> {
        let nextContext = try await self._userSteppedOffEarly(self.internalContext)
        return ScaleObserver<ScaleMachine.PowerDown>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }

    /// Hardware safety fallback
    public consuming func hardwareFault() async throws -> ScaleObserver<ScaleMachine.PowerDown> {
        let nextContext = try await self._hardwareFault(self.internalContext)
        return ScaleObserver<ScaleMachine.PowerDown>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }
}

// MARK: - Scale.Stabilized Transitions

extension ScaleObserver where State == ScaleMachine.Stabilized {
    /// Initiates electrical Body Impedance Analysis (Fat/Water %)
    public consuming func startBIA() async throws -> ScaleObserver<ScaleMachine.MeasuringImpedance> {
        let nextContext = try await self._startBIA(self.internalContext)
        return ScaleObserver<ScaleMachine.MeasuringImpedance>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }
}

// MARK: - Scale.MeasuringImpedance Transitions

extension ScaleObserver where State == ScaleMachine.MeasuringImpedance {
    /// Captures the BIA metrics and prepares for network transfer
    public consuming func biaComplete(metrics: BodyMetrics) async throws -> ScaleObserver<ScaleMachine.Syncing> {
        let nextContext = try await self._biaCompleteMetricsBodyMetrics(self.internalContext, metrics)
        return ScaleObserver<ScaleMachine.Syncing>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }

    /// Fallback: If the user is wearing socks, skip BIA and just sync the weight
    public consuming func bareFeetRequiredError() async throws -> ScaleObserver<ScaleMachine.Syncing> {
        let nextContext = try await self._bareFeetRequiredError(self.internalContext)
        return ScaleObserver<ScaleMachine.Syncing>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }
}

// MARK: - Scale.Syncing Transitions

extension ScaleObserver where State == ScaleMachine.Syncing {
    /// EMIT: The scale logic is done. It emits the combined payload and powers down.
    public consuming func syncData(payload: ScalePayload) async throws -> ScaleObserver<ScaleMachine.PowerDown> {
        let nextContext = try await self._syncDataPayloadScalePayload(self.internalContext, payload)
        return ScaleObserver<ScaleMachine.PowerDown>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedWeightDouble: self._weightLockedWeightDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteMetricsBodyMetrics: self._biaCompleteMetricsBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataPayloadScalePayload: self._syncDataPayloadScalePayload,
                _hardwareFault: self._hardwareFault
        )
    }
}

// MARK: - Scale Combined State

/// A runtime-friendly wrapper over all observer states.
public enum ScaleState: ~Copyable {
    case off(ScaleObserver<ScaleMachine.Off>)
    case wakingUp(ScaleObserver<ScaleMachine.WakingUp>)
    case tare(ScaleObserver<ScaleMachine.Tare>)
    case weighing(ScaleObserver<ScaleMachine.Weighing>)
    case stabilized(ScaleObserver<ScaleMachine.Stabilized>)
    case measuringImpedance(ScaleObserver<ScaleMachine.MeasuringImpedance>)
    case syncing(ScaleObserver<ScaleMachine.Syncing>)
    case powerDown(ScaleObserver<ScaleMachine.PowerDown>)

    public init(_ observer: consuming ScaleObserver<ScaleMachine.Off>) {
        self = .off(observer)
    }
}

extension ScaleState {
    public borrowing func withOff<R>(_ body: (borrowing ScaleObserver<ScaleMachine.Off>) throws -> R) rethrows -> R? {
        switch self {
        case let .off(observer):
            return try body(observer)

        case .wakingUp:
            return nil
        case .tare:
            return nil
        case .weighing:
            return nil
        case .stabilized:
            return nil
        case .measuringImpedance:
            return nil
        case .syncing:
            return nil
        case .powerDown:
            return nil
        }
    }

    public borrowing func withWakingUp<R>(_ body: (borrowing ScaleObserver<ScaleMachine.WakingUp>) throws -> R) rethrows -> R? {
        switch self {
        case let .wakingUp(observer):
            return try body(observer)

        case .off:
            return nil
        case .tare:
            return nil
        case .weighing:
            return nil
        case .stabilized:
            return nil
        case .measuringImpedance:
            return nil
        case .syncing:
            return nil
        case .powerDown:
            return nil
        }
    }

    public borrowing func withTare<R>(_ body: (borrowing ScaleObserver<ScaleMachine.Tare>) throws -> R) rethrows -> R? {
        switch self {
        case let .tare(observer):
            return try body(observer)

        case .off:
            return nil
        case .wakingUp:
            return nil
        case .weighing:
            return nil
        case .stabilized:
            return nil
        case .measuringImpedance:
            return nil
        case .syncing:
            return nil
        case .powerDown:
            return nil
        }
    }

    public borrowing func withWeighing<R>(_ body: (borrowing ScaleObserver<ScaleMachine.Weighing>) throws -> R) rethrows -> R? {
        switch self {
        case let .weighing(observer):
            return try body(observer)

        case .off:
            return nil
        case .wakingUp:
            return nil
        case .tare:
            return nil
        case .stabilized:
            return nil
        case .measuringImpedance:
            return nil
        case .syncing:
            return nil
        case .powerDown:
            return nil
        }
    }

    public borrowing func withStabilized<R>(_ body: (borrowing ScaleObserver<ScaleMachine.Stabilized>) throws -> R) rethrows -> R? {
        switch self {
        case let .stabilized(observer):
            return try body(observer)

        case .off:
            return nil
        case .wakingUp:
            return nil
        case .tare:
            return nil
        case .weighing:
            return nil
        case .measuringImpedance:
            return nil
        case .syncing:
            return nil
        case .powerDown:
            return nil
        }
    }

    public borrowing func withMeasuringImpedance<R>(_ body: (borrowing ScaleObserver<ScaleMachine.MeasuringImpedance>) throws -> R) rethrows -> R? {
        switch self {
        case let .measuringImpedance(observer):
            return try body(observer)

        case .off:
            return nil
        case .wakingUp:
            return nil
        case .tare:
            return nil
        case .weighing:
            return nil
        case .stabilized:
            return nil
        case .syncing:
            return nil
        case .powerDown:
            return nil
        }
    }

    public borrowing func withSyncing<R>(_ body: (borrowing ScaleObserver<ScaleMachine.Syncing>) throws -> R) rethrows -> R? {
        switch self {
        case let .syncing(observer):
            return try body(observer)

        case .off:
            return nil
        case .wakingUp:
            return nil
        case .tare:
            return nil
        case .weighing:
            return nil
        case .stabilized:
            return nil
        case .measuringImpedance:
            return nil
        case .powerDown:
            return nil
        }
    }

    public borrowing func withPowerDown<R>(_ body: (borrowing ScaleObserver<ScaleMachine.PowerDown>) throws -> R) rethrows -> R? {
        switch self {
        case let .powerDown(observer):
            return try body(observer)

        case .off:
            return nil
        case .wakingUp:
            return nil
        case .tare:
            return nil
        case .weighing:
            return nil
        case .stabilized:
            return nil
        case .measuringImpedance:
            return nil
        case .syncing:
            return nil
        }
    }


    /// Attempts the `footTap` transition from the current wrapper state.
    public consuming func footTap() async throws -> Self {
        switch consume self {
    case let .off(observer):
        let next = try await observer.footTap()
        return .wakingUp(next)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        return .weighing(observer)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `hardwareReady` transition from the current wrapper state.
    public consuming func hardwareReady() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        let next = try await observer.hardwareReady()
        return .tare(next)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        return .weighing(observer)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `zeroAchieved` transition from the current wrapper state.
    public consuming func zeroAchieved() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        let next = try await observer.zeroAchieved()
        return .weighing(next)
    case let .weighing(observer):
        return .weighing(observer)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `weightLocked` transition from the current wrapper state.
    public consuming func weightLocked(weight: Double) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        let next = try await observer.weightLocked(weight: weight)
        return .stabilized(next)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `userSteppedOffEarly` transition from the current wrapper state.
    public consuming func userSteppedOffEarly() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        let next = try await observer.userSteppedOffEarly()
        return .powerDown(next)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `startBIA` transition from the current wrapper state.
    public consuming func startBIA() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        return .weighing(observer)
    case let .stabilized(observer):
        let next = try await observer.startBIA()
        return .measuringImpedance(next)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `biaComplete` transition from the current wrapper state.
    public consuming func biaComplete(metrics: BodyMetrics) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        return .weighing(observer)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        let next = try await observer.biaComplete(metrics: metrics)
        return .syncing(next)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `bareFeetRequiredError` transition from the current wrapper state.
    public consuming func bareFeetRequiredError() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        return .weighing(observer)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        let next = try await observer.bareFeetRequiredError()
        return .syncing(next)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `syncData` transition from the current wrapper state.
    public consuming func syncData(payload: ScalePayload) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        return .weighing(observer)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        let next = try await observer.syncData(payload: payload)
        return .powerDown(next)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }

    /// Attempts the `hardwareFault` transition from the current wrapper state.
    public consuming func hardwareFault() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .wakingUp(observer):
        return .wakingUp(observer)
    case let .tare(observer):
        return .tare(observer)
    case let .weighing(observer):
        let next = try await observer.hardwareFault()
        return .powerDown(next)
    case let .stabilized(observer):
        return .stabilized(observer)
    case let .measuringImpedance(observer):
        return .measuringImpedance(observer)
    case let .syncing(observer):
        return .syncing(observer)
    case let .powerDown(observer):
        return .powerDown(observer)
        }
    }
}

// MARK: - Scale Orchestrator

/// Actor wrapper that coordinates the parent machine with composed machine state lifecycles.
public actor ScaleOrchestrator {
    private enum Phase: Sendable {
        case off
        case wakingUp
        case tare
        case weighing
        case stabilized
        case measuringImpedance
        case syncing
        case powerDown
    }

    private var phase: Phase
    private var bleState: BLEState?
    private let makeBLEState: @Sendable () -> BLEState

    public init(
        initialState: consuming ScaleState,
        makeBLEState: @escaping @Sendable () -> BLEState
    ) {
        switch consume initialState {
        case .off:
            self.phase = .off
        case .wakingUp:
            self.phase = .wakingUp
        case .tare:
            self.phase = .tare
        case .weighing:
            self.phase = .weighing
        case .stabilized:
            self.phase = .stabilized
        case .measuringImpedance:
            self.phase = .measuringImpedance
        case .syncing:
            self.phase = .syncing
        case .powerDown:
            self.phase = .powerDown
        }
        self.bleState = nil
        self.makeBLEState = makeBLEState
    }

    public func footTap() async throws {
        if case .off = self.phase {
            self.phase = .wakingUp
        }
    }

    public func hardwareReady() async throws {
        if case .wakingUp = self.phase {
            self.phase = .tare
            if self.bleState == nil {
                self.bleState = self.makeBLEState()
            }
        }
    }

    public func zeroAchieved() async throws {
        if case .tare = self.phase {
            self.phase = .weighing
        }
    }

    public func weightLocked(weight: Double) async throws {
        _ = weight
        if case .weighing = self.phase {
            self.phase = .stabilized
        }
    }

    public func userSteppedOffEarly() async throws {
        if case .weighing = self.phase {
            self.phase = .powerDown
        }
    }

    public func startBIA() async throws {
        if case .stabilized = self.phase {
            self.phase = .measuringImpedance
        }
    }

    public func biaComplete(metrics: BodyMetrics) async throws {
        _ = metrics
        if case .measuringImpedance = self.phase {
            self.phase = .syncing
        }
    }

    public func bareFeetRequiredError() async throws {
        if case .measuringImpedance = self.phase {
            self.phase = .syncing
        }
    }

    public func syncData(payload: ScalePayload) async throws {
        _ = payload
        if case .syncing = self.phase {
            self.phase = .powerDown
        }
    }

    public func hardwareFault() async throws {
        if case .weighing = self.phase {
            self.phase = .powerDown
        }
    }
}

// MARK: - Scale Client

/// Dependency client entry point for constructing Scale observers.
public struct ScaleClient: Sendable {
    public var makeScale: @Sendable () -> ScaleObserver<ScaleMachine.Off>

    public init(makeScale: @escaping @Sendable () -> ScaleObserver<ScaleMachine.Off>) {
        self.makeScale = makeScale
    }
}

extension ScaleClient: DependencyKey {
    public static let testValue = Self(
        makeScale: {
                    fatalError("Configure ScaleClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeScale: {
                    fatalError("Configure ScaleClient.previewValue in previews.")
                }
    )

    public static let liveValue = Self(
        makeScale: {
                    fatalError("Configure ScaleClient.liveValue in your app target.")
                }
    )
}

extension DependencyValues {
    /// Accessor for the generated ScaleClient dependency.
    public var scale: ScaleClient {
        get { self[ScaleClient.self] }
        set { self[ScaleClient.self] = newValue }
    }
}

import Foundation
import Dependencies

// MARK: - Scale Typestate Markers

public enum ScaleStateOff {}
public enum ScaleStateWakingUp {}
public enum ScaleStateTare {}
public enum ScaleStateWeighing {}
public enum ScaleStateStabilized {}
public enum ScaleStateMeasuringImpedance {}
public enum ScaleStateSyncing {}
public enum ScaleStatePowerDown {}

// MARK: - Scale State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct ScaleMachine<State>: ~Copyable {
    private var internalContext: ScaleContext

    private let _footTap: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _hardwareReady: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _zeroAchieved: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _weightLockedDouble: @Sendable (ScaleContext, Double) async throws -> ScaleContext
    private let _userSteppedOffEarly: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _startBIA: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _biaCompleteBodyMetrics: @Sendable (ScaleContext, BodyMetrics) async throws -> ScaleContext
    private let _bareFeetRequiredError: @Sendable (ScaleContext) async throws -> ScaleContext
    private let _syncDataScalePayload: @Sendable (ScaleContext, ScalePayload) async throws -> ScaleContext
    private let _hardwareFault: @Sendable (ScaleContext) async throws -> ScaleContext
    var _bleState: BLEState?
    let _makeBLE: @Sendable () -> BLEState
    public init(
        internalContext: ScaleContext,
        _footTap: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _hardwareReady: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _zeroAchieved: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _weightLockedDouble: @escaping @Sendable (ScaleContext, Double) async throws -> ScaleContext,
        _userSteppedOffEarly: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _startBIA: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _biaCompleteBodyMetrics: @escaping @Sendable (ScaleContext, BodyMetrics) async throws -> ScaleContext,
        _bareFeetRequiredError: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _syncDataScalePayload: @escaping @Sendable (ScaleContext, ScalePayload) async throws -> ScaleContext,
        _hardwareFault: @escaping @Sendable (ScaleContext) async throws -> ScaleContext,
        _bleState: consuming BLEState? = .none,
        _makeBLE: @escaping @Sendable () -> BLEState
    ) {
        self.internalContext = internalContext

        self._footTap = _footTap
        self._hardwareReady = _hardwareReady
        self._zeroAchieved = _zeroAchieved
        self._weightLockedDouble = _weightLockedDouble
        self._userSteppedOffEarly = _userSteppedOffEarly
        self._startBIA = _startBIA
        self._biaCompleteBodyMetrics = _biaCompleteBodyMetrics
        self._bareFeetRequiredError = _bareFeetRequiredError
        self._syncDataScalePayload = _syncDataScalePayload
        self._hardwareFault = _hardwareFault
        self._bleState = _bleState
        self._makeBLE = _makeBLE
    }

    /// Access the internal context while preserving borrowing semantics.
    public borrowing func withInternalContext<R>(_ body: (borrowing ScaleContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }

    /// Advances the embedded BLE state machine using `body`.
    internal consuming func _advancingBLEState(
        via body: (consuming BLEState) async throws -> BLEState?
    ) async rethrows -> Self {
        let internalContext = self.internalContext
        let _footTap = self._footTap
        let _hardwareReady = self._hardwareReady
        let _zeroAchieved = self._zeroAchieved
        let _weightLockedDouble = self._weightLockedDouble
        let _userSteppedOffEarly = self._userSteppedOffEarly
        let _startBIA = self._startBIA
        let _biaCompleteBodyMetrics = self._biaCompleteBodyMetrics
        let _bareFeetRequiredError = self._bareFeetRequiredError
        let _syncDataScalePayload = self._syncDataScalePayload
        let _hardwareFault = self._hardwareFault
        let _makeBLE = self._makeBLE
        let ble = self._bleState
        let next: BLEState?
        if var sub = ble { next = try await body(consume sub) } else { next = .none }
        return Self(
            internalContext: internalContext,
            _footTap: _footTap,
            _hardwareReady: _hardwareReady,
            _zeroAchieved: _zeroAchieved,
            _weightLockedDouble: _weightLockedDouble,
            _userSteppedOffEarly: _userSteppedOffEarly,
            _startBIA: _startBIA,
            _biaCompleteBodyMetrics: _biaCompleteBodyMetrics,
            _bareFeetRequiredError: _bareFeetRequiredError,
            _syncDataScalePayload: _syncDataScalePayload,
            _hardwareFault: _hardwareFault,
            _bleState: next,
            _makeBLE: _makeBLE
        )
    }
}

// MARK: - Scale.Off Transitions

extension ScaleMachine where State == ScaleStateOff {
    /// Wakes the scale hardware from deep sleep
    public consuming func footTap() async throws -> ScaleMachine<ScaleStateWakingUp> {
        let nextContext = try await self._footTap(self.internalContext)
        return ScaleMachine<ScaleStateWakingUp>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - Scale.WakingUp Transitions

extension ScaleMachine where State == ScaleStateWakingUp {
    /// FORK: Hardware initialized. Move to Tare, and simultaneously spawn the BLE radio machine.
    public consuming func hardwareReady() async throws -> ScaleMachine<ScaleStateTare> {
        let nextContext = try await self._hardwareReady(self.internalContext)
        return ScaleMachine<ScaleStateTare>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._makeBLE(),
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - Scale.Tare Transitions

extension ScaleMachine where State == ScaleStateTare {
    /// Calibrates the load cells to zero
    public consuming func zeroAchieved() async throws -> ScaleMachine<ScaleStateWeighing> {
        let nextContext = try await self._zeroAchieved(self.internalContext)
        return ScaleMachine<ScaleStateWeighing>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - Scale.Weighing Transitions

extension ScaleMachine where State == ScaleStateWeighing {
    /// Locks in the physical weight measurement
    public consuming func weightLocked(weight: Double) async throws -> ScaleMachine<ScaleStateStabilized> {
        let nextContext = try await self._weightLockedDouble(self.internalContext, weight)
        return ScaleMachine<ScaleStateStabilized>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Graceful exit if the user steps off before a lock is achieved
    public consuming func userSteppedOffEarly() async throws -> ScaleMachine<ScaleStatePowerDown> {
        let nextContext = try await self._userSteppedOffEarly(self.internalContext)
        return ScaleMachine<ScaleStatePowerDown>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Hardware safety fallback
    public consuming func hardwareFault() async throws -> ScaleMachine<ScaleStatePowerDown> {
        let nextContext = try await self._hardwareFault(self.internalContext)
        return ScaleMachine<ScaleStatePowerDown>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - Scale.Stabilized Transitions

extension ScaleMachine where State == ScaleStateStabilized {
    /// Initiates electrical Body Impedance Analysis (Fat/Water %)
    public consuming func startBIA() async throws -> ScaleMachine<ScaleStateMeasuringImpedance> {
        let nextContext = try await self._startBIA(self.internalContext)
        return ScaleMachine<ScaleStateMeasuringImpedance>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - Scale.MeasuringImpedance Transitions

extension ScaleMachine where State == ScaleStateMeasuringImpedance {
    /// Captures the BIA metrics and prepares for network transfer
    public consuming func biaComplete(metrics: BodyMetrics) async throws -> ScaleMachine<ScaleStateSyncing> {
        let nextContext = try await self._biaCompleteBodyMetrics(self.internalContext, metrics)
        return ScaleMachine<ScaleStateSyncing>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Fallback: If the user is wearing socks, skip BIA and just sync the weight
    public consuming func bareFeetRequiredError() async throws -> ScaleMachine<ScaleStateSyncing> {
        let nextContext = try await self._bareFeetRequiredError(self.internalContext)
        return ScaleMachine<ScaleStateSyncing>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - Scale.Syncing Transitions

extension ScaleMachine where State == ScaleStateSyncing {
    /// EMIT: The scale logic is done. It emits the combined payload and powers down.
    public consuming func syncData(payload: ScalePayload) async throws -> ScaleMachine<ScaleStatePowerDown> {
        let nextContext = try await self._syncDataScalePayload(self.internalContext, payload)
        return ScaleMachine<ScaleStatePowerDown>(
            internalContext: nextContext,
                _footTap: self._footTap,
                _hardwareReady: self._hardwareReady,
                _zeroAchieved: self._zeroAchieved,
                _weightLockedDouble: self._weightLockedDouble,
                _userSteppedOffEarly: self._userSteppedOffEarly,
                _startBIA: self._startBIA,
                _biaCompleteBodyMetrics: self._biaCompleteBodyMetrics,
                _bareFeetRequiredError: self._bareFeetRequiredError,
                _syncDataScalePayload: self._syncDataScalePayload,
                _hardwareFault: self._hardwareFault,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - Scale Combined State

/// A runtime-friendly wrapper over all observer states.
public enum ScaleState: ~Copyable {
    case off(ScaleMachine<ScaleStateOff>)
    case wakingUp(ScaleMachine<ScaleStateWakingUp>)
    case tare(ScaleMachine<ScaleStateTare>)
    case weighing(ScaleMachine<ScaleStateWeighing>)
    case stabilized(ScaleMachine<ScaleStateStabilized>)
    case measuringImpedance(ScaleMachine<ScaleStateMeasuringImpedance>)
    case syncing(ScaleMachine<ScaleStateSyncing>)
    case powerDown(ScaleMachine<ScaleStatePowerDown>)

    public init(_ machine: consuming ScaleMachine<ScaleStateOff>) {
        self = .off(machine)
    }
}

extension ScaleState {
    public borrowing func withOff<R>(_ body: (borrowing ScaleMachine<ScaleStateOff>) throws -> R) rethrows -> R? {
        switch self {
        case let .off(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withWakingUp<R>(_ body: (borrowing ScaleMachine<ScaleStateWakingUp>) throws -> R) rethrows -> R? {
        switch self {
        case let .wakingUp(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withTare<R>(_ body: (borrowing ScaleMachine<ScaleStateTare>) throws -> R) rethrows -> R? {
        switch self {
        case let .tare(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withWeighing<R>(_ body: (borrowing ScaleMachine<ScaleStateWeighing>) throws -> R) rethrows -> R? {
        switch self {
        case let .weighing(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withStabilized<R>(_ body: (borrowing ScaleMachine<ScaleStateStabilized>) throws -> R) rethrows -> R? {
        switch self {
        case let .stabilized(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withMeasuringImpedance<R>(_ body: (borrowing ScaleMachine<ScaleStateMeasuringImpedance>) throws -> R) rethrows -> R? {
        switch self {
        case let .measuringImpedance(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withSyncing<R>(_ body: (borrowing ScaleMachine<ScaleStateSyncing>) throws -> R) rethrows -> R? {
        switch self {
        case let .syncing(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withPowerDown<R>(_ body: (borrowing ScaleMachine<ScaleStatePowerDown>) throws -> R) rethrows -> R? {
        switch self {
        case let .powerDown(observer):
            return try body(observer)
        default:
            return nil
        }
    }


    /// Attempts the `footTap` transition from the current wrapper state.
    public consuming func footTap() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .wakingUp(try await observer.footTap())
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
        return .tare(try await observer.hardwareReady())
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
        return .weighing(try await observer.zeroAchieved())
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
        return .stabilized(try await observer.weightLocked(weight: weight))
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
        return .powerDown(try await observer.userSteppedOffEarly())
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
        return .measuringImpedance(try await observer.startBIA())
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
        return .syncing(try await observer.biaComplete(metrics: metrics))
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
        return .syncing(try await observer.bareFeetRequiredError())
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
        return .powerDown(try await observer.syncData(payload: payload))
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
        return .powerDown(try await observer.hardwareFault())
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

extension ScaleState {
    /// Forwards the `powerOn` event to the embedded BLE machine.
    public consuming func blePowerOn() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.powerOn() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.powerOn() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.powerOn() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.powerOn() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.powerOn() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.powerOn() })
        }
    }

    /// Forwards the `radioReady` event to the embedded BLE machine.
    public consuming func bleRadioReady() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.radioReady() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.radioReady() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.radioReady() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.radioReady() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.radioReady() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.radioReady() })
        }
    }

    /// Forwards the `deviceDiscovered` event to the embedded BLE machine.
    public consuming func bleDeviceDiscovered(device: BLEDevice) async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.deviceDiscovered(device: device) })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.deviceDiscovered(device: device) })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.deviceDiscovered(device: device) })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.deviceDiscovered(device: device) })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.deviceDiscovered(device: device) })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.deviceDiscovered(device: device) })
        }
    }

    /// Forwards the `scanTimeout` event to the embedded BLE machine.
    public consuming func bleScanTimeout() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
        }
    }

    /// Forwards the `connectionEstablished` event to the embedded BLE machine.
    public consuming func bleConnectionEstablished() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
        }
    }

    /// Forwards the `connectionFailed` event to the embedded BLE machine.
    public consuming func bleConnectionFailed(reason: String) async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
        }
    }

    /// Forwards the `retry` event to the embedded BLE machine.
    public consuming func bleRetry() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.retry() })
        }
    }

    /// Forwards the `retriesExhausted` event to the embedded BLE machine.
    public consuming func bleRetriesExhausted() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
        }
    }

    /// Forwards the `startSync` event to the embedded BLE machine.
    public consuming func bleStartSync(payload: ScalePayload) async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.startSync(payload: payload) })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.startSync(payload: payload) })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.startSync(payload: payload) })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.startSync(payload: payload) })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.startSync(payload: payload) })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.startSync(payload: payload) })
        }
    }

    /// Forwards the `syncSucceeded` event to the embedded BLE machine.
    public consuming func bleSyncSucceeded() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.syncSucceeded() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.syncSucceeded() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.syncSucceeded() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.syncSucceeded() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.syncSucceeded() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.syncSucceeded() })
        }
    }

    /// Forwards the `syncFailed` event to the embedded BLE machine.
    public consuming func bleSyncFailed(reason: String) async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.syncFailed(reason: reason) })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.syncFailed(reason: reason) })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.syncFailed(reason: reason) })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.syncFailed(reason: reason) })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.syncFailed(reason: reason) })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.syncFailed(reason: reason) })
        }
    }

    /// Forwards the `peripheralDisconnected` event to the embedded BLE machine.
    public consuming func blePeripheralDisconnected() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
        }
    }

    /// Forwards the `resetRadio` event to the embedded BLE machine.
    public consuming func bleResetRadio() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.resetRadio() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.resetRadio() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.resetRadio() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.resetRadio() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.resetRadio() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.resetRadio() })
        }
    }

    /// Forwards the `powerDown` event to the embedded BLE machine.
    public consuming func blePowerDown() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(obs)
    case let .wakingUp(obs):
        return .wakingUp(obs)
    case let .tare(obs):
        return .tare(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .weighing(obs):
        return .weighing(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .stabilized(obs):
        return .stabilized(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .measuringImpedance(obs):
        return .measuringImpedance(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .syncing(obs):
        return .syncing(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .powerDown(obs):
        return .powerDown(try await obs._advancingBLEState { ble in try await ble.powerDown() })
        }
    }
}
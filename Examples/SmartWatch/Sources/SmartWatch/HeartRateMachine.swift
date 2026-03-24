import Foundation
import Dependencies

// MARK: - HeartRate Typestate Markers

public enum HeartRateStateOff {}
public enum HeartRateStateActivating {}
public enum HeartRateStateIdle {}
public enum HeartRateStateMeasuring {}
public enum HeartRateStateSensorLost {}
public enum HeartRateStateError {}
public enum HeartRateStateTerminated {}

// MARK: - HeartRate State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct HeartRateMachine<State>: ~Copyable {
    private var internalContext: HeartRateContext

    fileprivate let _activate: @Sendable (HeartRateContext) async throws -> HeartRateContext
    fileprivate let _sensorReady: @Sendable (HeartRateContext) async throws -> HeartRateContext
    fileprivate let _sensorFailedString: @Sendable (HeartRateContext, String) async throws -> HeartRateContext
    fileprivate let _startMeasurement: @Sendable (HeartRateContext) async throws -> HeartRateContext
    fileprivate let _measurementCompleteInt: @Sendable (HeartRateContext, Int) async throws -> HeartRateContext
    fileprivate let _sensorContactLost: @Sendable (HeartRateContext) async throws -> HeartRateContext
    fileprivate let _sensorContactRestored: @Sendable (HeartRateContext) async throws -> HeartRateContext
    fileprivate let _contactTimeout: @Sendable (HeartRateContext) async throws -> HeartRateContext
    fileprivate let _reset: @Sendable (HeartRateContext) async throws -> HeartRateContext
    fileprivate let _deactivate: @Sendable (HeartRateContext) async throws -> HeartRateContext
    var _bleState: BLEState?
    let _makeBLE: @Sendable () -> BLEState
    internal init(
        internalContext: HeartRateContext,
        _activate: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _sensorReady: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _sensorFailedString: @escaping @Sendable (HeartRateContext, String) async throws -> HeartRateContext,
        _startMeasurement: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _measurementCompleteInt: @escaping @Sendable (HeartRateContext, Int) async throws -> HeartRateContext,
        _sensorContactLost: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _sensorContactRestored: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _contactTimeout: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _reset: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _deactivate: @escaping @Sendable (HeartRateContext) async throws -> HeartRateContext,
        _bleState: consuming BLEState? = .none,
        _makeBLE: @escaping @Sendable () -> BLEState
    ) {
        self.internalContext = internalContext

        self._activate = _activate
        self._sensorReady = _sensorReady
        self._sensorFailedString = _sensorFailedString
        self._startMeasurement = _startMeasurement
        self._measurementCompleteInt = _measurementCompleteInt
        self._sensorContactLost = _sensorContactLost
        self._sensorContactRestored = _sensorContactRestored
        self._contactTimeout = _contactTimeout
        self._reset = _reset
        self._deactivate = _deactivate
        self._bleState = _bleState
        self._makeBLE = _makeBLE
    }

    /// Access the internal context while preserving borrowing semantics.
    internal borrowing func withInternalContext<R>(_ body: (borrowing HeartRateContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }

    /// Advances the embedded BLE state machine using `body`.
    internal consuming func _advancingBLEState(
        via body: (consuming BLEState) async throws -> BLEState?
    ) async rethrows -> Self {
        let internalContext = self.internalContext
        let _activate = self._activate
        let _sensorReady = self._sensorReady
        let _sensorFailedString = self._sensorFailedString
        let _startMeasurement = self._startMeasurement
        let _measurementCompleteInt = self._measurementCompleteInt
        let _sensorContactLost = self._sensorContactLost
        let _sensorContactRestored = self._sensorContactRestored
        let _contactTimeout = self._contactTimeout
        let _reset = self._reset
        let _deactivate = self._deactivate
        let _makeBLE = self._makeBLE
        let ble = self._bleState
        let next: BLEState?
        if var sub = ble { next = try await body(consume sub) } else { next = .none }
        return Self(
            internalContext: internalContext,
            _activate: _activate,
            _sensorReady: _sensorReady,
            _sensorFailedString: _sensorFailedString,
            _startMeasurement: _startMeasurement,
            _measurementCompleteInt: _measurementCompleteInt,
            _sensorContactLost: _sensorContactLost,
            _sensorContactRestored: _sensorContactRestored,
            _contactTimeout: _contactTimeout,
            _reset: _reset,
            _deactivate: _deactivate,
            _bleState: next,
            _makeBLE: _makeBLE
        )
    }
}

// MARK: - HeartRate.Off Transitions

extension HeartRateMachine where State == HeartRateStateOff {
    /// Activate the heart rate sensor and simultaneously spawn the BLE machine at Off.
    /// The coordinator must then drive the BLE through Scanning → Connecting → Connected
    /// before the sensor is ready to take measurements.
    public consuming func activate() async throws -> HeartRateMachine<HeartRateStateActivating> {
        let nextContext = try await self._activate(self.internalContext)
        return HeartRateMachine<HeartRateStateActivating>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._makeBLE(),
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - HeartRate.Activating Transitions

extension HeartRateMachine where State == HeartRateStateActivating {
    /// BLE is Connected and the HR optical sensor has passed self-check
    public consuming func sensorReady() async throws -> HeartRateMachine<HeartRateStateIdle> {
        let nextContext = try await self._sensorReady(self.internalContext)
        return HeartRateMachine<HeartRateStateIdle>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Hardware self-check failed (sensor obstructed, hardware fault, etc.)
    public consuming func sensorFailed(reason: String) async throws -> HeartRateMachine<HeartRateStateError> {
        let nextContext = try await self._sensorFailedString(self.internalContext, reason)
        return HeartRateMachine<HeartRateStateError>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - HeartRate.Idle Transitions

extension HeartRateMachine where State == HeartRateStateIdle {
    /// Request a single heart-rate measurement from the optical sensor
    public consuming func startMeasurement() async throws -> HeartRateMachine<HeartRateStateMeasuring> {
        let nextContext = try await self._startMeasurement(self.internalContext)
        return HeartRateMachine<HeartRateStateMeasuring>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Clean shutdown from any running state
    public consuming func deactivate() async throws -> HeartRateMachine<HeartRateStateTerminated> {
        let nextContext = try await self._deactivate(self.internalContext)
        return HeartRateMachine<HeartRateStateTerminated>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - HeartRate.Measuring Transitions

extension HeartRateMachine where State == HeartRateStateMeasuring {
    /// Sensor has produced a reliable BPM reading; return to Idle, ready for next sample
    public consuming func measurementComplete(bpm: Int) async throws -> HeartRateMachine<HeartRateStateIdle> {
        let nextContext = try await self._measurementCompleteInt(self.internalContext, bpm)
        return HeartRateMachine<HeartRateStateIdle>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Sensor lost contact with skin (watch removed or shifted)
    public consuming func sensorContactLost() async throws -> HeartRateMachine<HeartRateStateSensorLost> {
        let nextContext = try await self._sensorContactLost(self.internalContext)
        return HeartRateMachine<HeartRateStateSensorLost>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Handles the `deactivate` transition from Measuring to Terminated.
    public consuming func deactivate() async throws -> HeartRateMachine<HeartRateStateTerminated> {
        let nextContext = try await self._deactivate(self.internalContext)
        return HeartRateMachine<HeartRateStateTerminated>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - HeartRate.SensorLost Transitions

extension HeartRateMachine where State == HeartRateStateSensorLost {
    /// Skin contact restored; resume measurement from where the sensor lost contact
    public consuming func sensorContactRestored() async throws -> HeartRateMachine<HeartRateStateMeasuring> {
        let nextContext = try await self._sensorContactRestored(self.internalContext)
        return HeartRateMachine<HeartRateStateMeasuring>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Sensor contact not restored within the allowed window
    public consuming func contactTimeout() async throws -> HeartRateMachine<HeartRateStateError> {
        let nextContext = try await self._contactTimeout(self.internalContext)
        return HeartRateMachine<HeartRateStateError>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - HeartRate.Error Transitions

extension HeartRateMachine where State == HeartRateStateError {
    /// Unrecoverable sensor fault; reset the whole stack
    public consuming func reset() async throws -> HeartRateMachine<HeartRateStateOff> {
        let nextContext = try await self._reset(self.internalContext)
        return HeartRateMachine<HeartRateStateOff>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }

    /// Handles the `deactivate` transition from Error to Terminated.
    public consuming func deactivate() async throws -> HeartRateMachine<HeartRateStateTerminated> {
        let nextContext = try await self._deactivate(self.internalContext)
        return HeartRateMachine<HeartRateStateTerminated>(
            internalContext: nextContext,
                _activate: self._activate,
                _sensorReady: self._sensorReady,
                _sensorFailedString: self._sensorFailedString,
                _startMeasurement: self._startMeasurement,
                _measurementCompleteInt: self._measurementCompleteInt,
                _sensorContactLost: self._sensorContactLost,
                _sensorContactRestored: self._sensorContactRestored,
                _contactTimeout: self._contactTimeout,
                _reset: self._reset,
                _deactivate: self._deactivate,
                _bleState: self._bleState,
                _makeBLE: self._makeBLE
        )
    }
}

// MARK: - HeartRate Combined State

/// A runtime-friendly wrapper over all observer states.
public enum HeartRateState: ~Copyable {
    case off(HeartRateMachine<HeartRateStateOff>)
    case activating(HeartRateMachine<HeartRateStateActivating>)
    case idle(HeartRateMachine<HeartRateStateIdle>)
    case measuring(HeartRateMachine<HeartRateStateMeasuring>)
    case sensorLost(HeartRateMachine<HeartRateStateSensorLost>)
    case error(HeartRateMachine<HeartRateStateError>)
    case terminated(HeartRateMachine<HeartRateStateTerminated>)

    public init(_ machine: consuming HeartRateMachine<HeartRateStateOff>) {
        self = .off(machine)
    }
}

extension HeartRateState {
    public borrowing func withOff<R>(_ body: (borrowing HeartRateMachine<HeartRateStateOff>) throws -> R) rethrows -> R? {
        switch self {
        case let .off(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withActivating<R>(_ body: (borrowing HeartRateMachine<HeartRateStateActivating>) throws -> R) rethrows -> R? {
        switch self {
        case let .activating(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withIdle<R>(_ body: (borrowing HeartRateMachine<HeartRateStateIdle>) throws -> R) rethrows -> R? {
        switch self {
        case let .idle(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withMeasuring<R>(_ body: (borrowing HeartRateMachine<HeartRateStateMeasuring>) throws -> R) rethrows -> R? {
        switch self {
        case let .measuring(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withSensorLost<R>(_ body: (borrowing HeartRateMachine<HeartRateStateSensorLost>) throws -> R) rethrows -> R? {
        switch self {
        case let .sensorLost(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withError<R>(_ body: (borrowing HeartRateMachine<HeartRateStateError>) throws -> R) rethrows -> R? {
        switch self {
        case let .error(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withTerminated<R>(_ body: (borrowing HeartRateMachine<HeartRateStateTerminated>) throws -> R) rethrows -> R? {
        switch self {
        case let .terminated(observer):
            return try body(observer)
        default:
            return nil
        }
    }


    /// Attempts the `activate` transition from the current wrapper state.
    public consuming func activate() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .activating(try await observer.activate())
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .measuring(observer)
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `sensorReady` transition from the current wrapper state.
    public consuming func sensorReady() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .idle(try await observer.sensorReady())
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .measuring(observer)
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `sensorFailed` transition from the current wrapper state.
    public consuming func sensorFailed(reason: String) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .error(try await observer.sensorFailed(reason: reason))
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .measuring(observer)
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `startMeasurement` transition from the current wrapper state.
    public consuming func startMeasurement() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .measuring(try await observer.startMeasurement())
    case let .measuring(observer):
        return .measuring(observer)
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `measurementComplete` transition from the current wrapper state.
    public consuming func measurementComplete(bpm: Int) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .idle(try await observer.measurementComplete(bpm: bpm))
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `sensorContactLost` transition from the current wrapper state.
    public consuming func sensorContactLost() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .sensorLost(try await observer.sensorContactLost())
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `sensorContactRestored` transition from the current wrapper state.
    public consuming func sensorContactRestored() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .measuring(observer)
    case let .sensorLost(observer):
        return .measuring(try await observer.sensorContactRestored())
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `contactTimeout` transition from the current wrapper state.
    public consuming func contactTimeout() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .measuring(observer)
    case let .sensorLost(observer):
        return .error(try await observer.contactTimeout())
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `reset` transition from the current wrapper state.
    public consuming func reset() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .measuring(observer):
        return .measuring(observer)
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .off(try await observer.reset())
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `deactivate` transition from the current wrapper state.
    public consuming func deactivate() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .activating(observer):
        return .activating(observer)
    case let .idle(observer):
        return .terminated(try await observer.deactivate())
    case let .measuring(observer):
        return .terminated(try await observer.deactivate())
    case let .sensorLost(observer):
        return .sensorLost(observer)
    case let .error(observer):
        return .terminated(try await observer.deactivate())
    case let .terminated(observer):
        return .terminated(observer)
        }
    }
}

extension HeartRateState {
    /// Forwards the `startScan` event to the embedded BLE machine.
    public consuming func bleStartScan() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.startScan() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.startScan() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.startScan() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.startScan() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.startScan() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.startScan() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.startScan() })
        }
    }

    /// Forwards the `watchDiscovered` event to the embedded BLE machine.
    public consuming func bleWatchDiscovered(device: BLEDevice) async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.watchDiscovered(device: device) })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.watchDiscovered(device: device) })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.watchDiscovered(device: device) })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.watchDiscovered(device: device) })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.watchDiscovered(device: device) })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.watchDiscovered(device: device) })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.watchDiscovered(device: device) })
        }
    }

    /// Forwards the `scanTimeout` event to the embedded BLE machine.
    public consuming func bleScanTimeout() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.scanTimeout() })
        }
    }

    /// Forwards the `cancelScan` event to the embedded BLE machine.
    public consuming func bleCancelScan() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.cancelScan() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.cancelScan() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.cancelScan() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.cancelScan() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.cancelScan() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.cancelScan() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.cancelScan() })
        }
    }

    /// Forwards the `connectionEstablished` event to the embedded BLE machine.
    public consuming func bleConnectionEstablished() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.connectionEstablished() })
        }
    }

    /// Forwards the `connectionFailed` event to the embedded BLE machine.
    public consuming func bleConnectionFailed(reason: String) async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.connectionFailed(reason: reason) })
        }
    }

    /// Forwards the `retry` event to the embedded BLE machine.
    public consuming func bleRetry() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.retry() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.retry() })
        }
    }

    /// Forwards the `retriesExhausted` event to the embedded BLE machine.
    public consuming func bleRetriesExhausted() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.retriesExhausted() })
        }
    }

    /// Forwards the `peripheralDisconnected` event to the embedded BLE machine.
    public consuming func blePeripheralDisconnected() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.peripheralDisconnected() })
        }
    }

    /// Forwards the `userDisconnected` event to the embedded BLE machine.
    public consuming func bleUserDisconnected() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.userDisconnected() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.userDisconnected() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.userDisconnected() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.userDisconnected() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.userDisconnected() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.userDisconnected() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.userDisconnected() })
        }
    }

    /// Forwards the `resetAndScan` event to the embedded BLE machine.
    public consuming func bleResetAndScan() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.resetAndScan() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.resetAndScan() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.resetAndScan() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.resetAndScan() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.resetAndScan() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.resetAndScan() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.resetAndScan() })
        }
    }

    /// Forwards the `powerDown` event to the embedded BLE machine.
    public consuming func blePowerDown() async throws -> Self {
        switch consume self {
    case let .off(obs):
        return .off(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .activating(obs):
        return .activating(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .idle(obs):
        return .idle(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .measuring(obs):
        return .measuring(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .sensorLost(obs):
        return .sensorLost(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .error(obs):
        return .error(try await obs._advancingBLEState { ble in try await ble.powerDown() })
    case let .terminated(obs):
        return .terminated(try await obs._advancingBLEState { ble in try await ble.powerDown() })
        }
    }
}
import Foundation
import Dependencies

// MARK: - HeartRate Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct HeartRateClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> HeartRateContext
    typealias ActivateTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    typealias SensorReadyTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    typealias SensorFailedStringTransition = @Sendable (HeartRateContext, String) async throws -> HeartRateContext
    typealias StartMeasurementTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    typealias MeasurementCompleteIntTransition = @Sendable (HeartRateContext, Int) async throws -> HeartRateContext
    typealias SensorContactLostTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    typealias SensorContactRestoredTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    typealias ContactTimeoutTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    typealias ResetTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    typealias DeactivateTransition = @Sendable (HeartRateContext) async throws -> HeartRateContext
    let initialContext: InitialContextBuilder
    let activateTransition: ActivateTransition
    let sensorReadyTransition: SensorReadyTransition
    let sensorFailedStringTransition: SensorFailedStringTransition
    let startMeasurementTransition: StartMeasurementTransition
    let measurementCompleteIntTransition: MeasurementCompleteIntTransition
    let sensorContactLostTransition: SensorContactLostTransition
    let sensorContactRestoredTransition: SensorContactRestoredTransition
    let contactTimeoutTransition: ContactTimeoutTransition
    let resetTransition: ResetTransition
    let deactivateTransition: DeactivateTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        activateTransition: @escaping ActivateTransition,
        sensorReadyTransition: @escaping SensorReadyTransition,
        sensorFailedStringTransition: @escaping SensorFailedStringTransition,
        startMeasurementTransition: @escaping StartMeasurementTransition,
        measurementCompleteIntTransition: @escaping MeasurementCompleteIntTransition,
        sensorContactLostTransition: @escaping SensorContactLostTransition,
        sensorContactRestoredTransition: @escaping SensorContactRestoredTransition,
        contactTimeoutTransition: @escaping ContactTimeoutTransition,
        resetTransition: @escaping ResetTransition,
        deactivateTransition: @escaping DeactivateTransition
    ) {
        self.initialContext = initialContext
        self.activateTransition = activateTransition
        self.sensorReadyTransition = sensorReadyTransition
        self.sensorFailedStringTransition = sensorFailedStringTransition
        self.startMeasurementTransition = startMeasurementTransition
        self.measurementCompleteIntTransition = measurementCompleteIntTransition
        self.sensorContactLostTransition = sensorContactLostTransition
        self.sensorContactRestoredTransition = sensorContactRestoredTransition
        self.contactTimeoutTransition = contactTimeoutTransition
        self.resetTransition = resetTransition
        self.deactivateTransition = deactivateTransition
    }
}

extension HeartRateClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: HeartRateClientRuntime) -> Self {
        Self(
            makeHeartRate: { makeBLE in
                let context = runtime.initialContext()
                return HeartRateMachine<HeartRateStateOff>(
                    internalContext: context,
                _activate: runtime.activateTransition,
                _sensorReady: runtime.sensorReadyTransition,
                _sensorFailedString: runtime.sensorFailedStringTransition,
                _startMeasurement: runtime.startMeasurementTransition,
                _measurementCompleteInt: runtime.measurementCompleteIntTransition,
                _sensorContactLost: runtime.sensorContactLostTransition,
                _sensorContactRestored: runtime.sensorContactRestoredTransition,
                _contactTimeout: runtime.contactTimeoutTransition,
                _reset: runtime.resetTransition,
                _deactivate: runtime.deactivateTransition,
                _makeBLE: makeBLE
                )
            }
        )
    }
}

// MARK: - HeartRate Client

/// Dependency client entry point for constructing HeartRate state machines.
public struct HeartRateClient: Sendable {
    public var makeHeartRate: @Sendable (@escaping @Sendable () -> BLEState) -> HeartRateMachine<HeartRateStateOff>

    public init(makeHeartRate: @escaping @Sendable (@escaping @Sendable () -> BLEState) -> HeartRateMachine<HeartRateStateOff>) {
        self.makeHeartRate = makeHeartRate
    }
}
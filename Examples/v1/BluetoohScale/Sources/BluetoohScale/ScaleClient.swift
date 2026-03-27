import Foundation
import Dependencies

// MARK: - Scale Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct ScaleClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> ScaleContext
    typealias FootTapTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias HardwareReadyTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias ZeroAchievedTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias WeightLockedDoubleTransition = @Sendable (ScaleContext, Double) async throws -> ScaleContext
    typealias UserSteppedOffEarlyTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias StartBIATransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias BiaCompleteBodyMetricsTransition = @Sendable (ScaleContext, BodyMetrics) async throws -> ScaleContext
    typealias BareFeetRequiredErrorTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    typealias SyncDataScalePayloadTransition = @Sendable (ScaleContext, ScalePayload) async throws -> ScaleContext
    typealias HardwareFaultTransition = @Sendable (ScaleContext) async throws -> ScaleContext
    let initialContext: InitialContextBuilder
    let footTapTransition: FootTapTransition
    let hardwareReadyTransition: HardwareReadyTransition
    let zeroAchievedTransition: ZeroAchievedTransition
    let weightLockedDoubleTransition: WeightLockedDoubleTransition
    let userSteppedOffEarlyTransition: UserSteppedOffEarlyTransition
    let startBIATransition: StartBIATransition
    let biaCompleteBodyMetricsTransition: BiaCompleteBodyMetricsTransition
    let bareFeetRequiredErrorTransition: BareFeetRequiredErrorTransition
    let syncDataScalePayloadTransition: SyncDataScalePayloadTransition
    let hardwareFaultTransition: HardwareFaultTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        footTapTransition: @escaping FootTapTransition,
        hardwareReadyTransition: @escaping HardwareReadyTransition,
        zeroAchievedTransition: @escaping ZeroAchievedTransition,
        weightLockedDoubleTransition: @escaping WeightLockedDoubleTransition,
        userSteppedOffEarlyTransition: @escaping UserSteppedOffEarlyTransition,
        startBIATransition: @escaping StartBIATransition,
        biaCompleteBodyMetricsTransition: @escaping BiaCompleteBodyMetricsTransition,
        bareFeetRequiredErrorTransition: @escaping BareFeetRequiredErrorTransition,
        syncDataScalePayloadTransition: @escaping SyncDataScalePayloadTransition,
        hardwareFaultTransition: @escaping HardwareFaultTransition
    ) {
        self.initialContext = initialContext
        self.footTapTransition = footTapTransition
        self.hardwareReadyTransition = hardwareReadyTransition
        self.zeroAchievedTransition = zeroAchievedTransition
        self.weightLockedDoubleTransition = weightLockedDoubleTransition
        self.userSteppedOffEarlyTransition = userSteppedOffEarlyTransition
        self.startBIATransition = startBIATransition
        self.biaCompleteBodyMetricsTransition = biaCompleteBodyMetricsTransition
        self.bareFeetRequiredErrorTransition = bareFeetRequiredErrorTransition
        self.syncDataScalePayloadTransition = syncDataScalePayloadTransition
        self.hardwareFaultTransition = hardwareFaultTransition
    }
}

extension ScaleClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: ScaleClientRuntime) -> Self {
        Self(
            makeScale: { makeBLE in
                let context = runtime.initialContext()
                return ScaleMachine<ScaleStateOff>(
                    internalContext: context,
                _footTap: runtime.footTapTransition,
                _hardwareReady: runtime.hardwareReadyTransition,
                _zeroAchieved: runtime.zeroAchievedTransition,
                _weightLockedDouble: runtime.weightLockedDoubleTransition,
                _userSteppedOffEarly: runtime.userSteppedOffEarlyTransition,
                _startBIA: runtime.startBIATransition,
                _biaCompleteBodyMetrics: runtime.biaCompleteBodyMetricsTransition,
                _bareFeetRequiredError: runtime.bareFeetRequiredErrorTransition,
                _syncDataScalePayload: runtime.syncDataScalePayloadTransition,
                _hardwareFault: runtime.hardwareFaultTransition,
                _makeBLE: makeBLE
                )
            }
        )
    }
}

// MARK: - Scale Client

/// Dependency client entry point for constructing Scale state machines.
public struct ScaleClient: Sendable {
    public var makeScale: @Sendable (@escaping @Sendable () -> BLEState) -> ScaleMachine<ScaleStateOff>

    public init(makeScale: @escaping @Sendable (@escaping @Sendable () -> BLEState) -> ScaleMachine<ScaleStateOff>) {
        self.makeScale = makeScale
    }
}
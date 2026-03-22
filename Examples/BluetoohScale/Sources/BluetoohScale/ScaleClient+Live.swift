import Foundation

// MARK: - ScaleClient Live

public extension ScaleClient {
    static func makeLive() -> Self {
        .fromRuntime(.init(
            initialContext: { .init() },
            footTapTransition: { ctx in ctx },
            hardwareReadyTransition: { ctx in ctx },
            zeroAchievedTransition: { ctx in ctx },
            weightLockedWeightDoubleTransition: { ctx, weight in
                var c = ctx; c.latestWeightKg = weight; return c
            },
            userSteppedOffEarlyTransition: { ctx in ctx },
            startBIATransition: { ctx in ctx },
            biaCompleteMetricsBodyMetricsTransition: { ctx, metrics in
                var c = ctx; c.latestMetrics = metrics; return c
            },
            bareFeetRequiredErrorTransition: { ctx in ctx },
            syncDataPayloadScalePayloadTransition: { ctx, _ in ctx },
            hardwareFaultTransition: { ctx in ctx }
        ))
    }
}

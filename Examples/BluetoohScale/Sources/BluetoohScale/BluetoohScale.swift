import Foundation

public enum ScaleVendor: String, Sendable, CaseIterable {
    case withings
    case garmin
}

public struct BLEDevice: Sendable, Equatable {
    public var identifier: UUID
    public var name: String

    public init(identifier: UUID = UUID(), name: String) {
        self.identifier = identifier
        self.name = name
    }
}

public struct BodyMetrics: Sendable, Equatable {
    public var bodyFatPercentage: Double
    public var bodyWaterPercentage: Double
    public var muscleMassKg: Double

    public init(
        bodyFatPercentage: Double,
        bodyWaterPercentage: Double,
        muscleMassKg: Double
    ) {
        self.bodyFatPercentage = bodyFatPercentage
        self.bodyWaterPercentage = bodyWaterPercentage
        self.muscleMassKg = muscleMassKg
    }
}

public struct ScalePayload: Sendable, Equatable {
    public var vendor: ScaleVendor
    public var weightKg: Double
    public var metrics: BodyMetrics?
    public var measuredAt: Date

    public init(
        vendor: ScaleVendor,
        weightKg: Double,
        metrics: BodyMetrics?,
        measuredAt: Date = Date()
    ) {
        self.vendor = vendor
        self.weightKg = weightKg
        self.metrics = metrics
        self.measuredAt = measuredAt
    }
}

public struct BLEContext: Sendable {
    public var vendor: ScaleVendor
    public var lastSeenDevice: BLEDevice?

    public init(vendor: ScaleVendor = .withings, lastSeenDevice: BLEDevice? = nil) {
        self.vendor = vendor
        self.lastSeenDevice = lastSeenDevice
    }
}

public struct ScaleContext: Sendable {
    public var vendor: ScaleVendor
    public var latestWeightKg: Double?
    public var latestMetrics: BodyMetrics?

    public init(
        vendor: ScaleVendor = .withings,
        latestWeightKg: Double? = nil,
        latestMetrics: BodyMetrics? = nil
    ) {
        self.vendor = vendor
        self.latestWeightKg = latestWeightKg
        self.latestMetrics = latestMetrics
    }
}

public struct BLERuntimeHandlers: Sendable {
    public var powerOn: @Sendable () async throws -> Void
    public var radioReady: @Sendable () async throws -> Void
    public var deviceDiscovered: @Sendable (BLEDevice) async throws -> Void
    public var scanTimeout: @Sendable () async throws -> Void
    public var connectionEstablished: @Sendable () async throws -> Void
    public var connectionFailed: @Sendable (String) async throws -> Void
    public var retry: @Sendable () async throws -> Void
    public var retriesExhausted: @Sendable () async throws -> Void
    public var startSync: @Sendable (ScalePayload) async throws -> Void
    public var syncSucceeded: @Sendable () async throws -> Void
    public var syncFailed: @Sendable (String) async throws -> Void
    public var peripheralDisconnected: @Sendable () async throws -> Void
    public var resetRadio: @Sendable () async throws -> Void
    public var powerDown: @Sendable () async throws -> Void

    public init(
        powerOn: @escaping @Sendable () async throws -> Void = {},
        radioReady: @escaping @Sendable () async throws -> Void = {},
        deviceDiscovered: @escaping @Sendable (BLEDevice) async throws -> Void = { _ in },
        scanTimeout: @escaping @Sendable () async throws -> Void = {},
        connectionEstablished: @escaping @Sendable () async throws -> Void = {},
        connectionFailed: @escaping @Sendable (String) async throws -> Void = { _ in },
        retry: @escaping @Sendable () async throws -> Void = {},
        retriesExhausted: @escaping @Sendable () async throws -> Void = {},
        startSync: @escaping @Sendable (ScalePayload) async throws -> Void = { _ in },
        syncSucceeded: @escaping @Sendable () async throws -> Void = {},
        syncFailed: @escaping @Sendable (String) async throws -> Void = { _ in },
        peripheralDisconnected: @escaping @Sendable () async throws -> Void = {},
        resetRadio: @escaping @Sendable () async throws -> Void = {},
        powerDown: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.powerOn = powerOn
        self.radioReady = radioReady
        self.deviceDiscovered = deviceDiscovered
        self.scanTimeout = scanTimeout
        self.connectionEstablished = connectionEstablished
        self.connectionFailed = connectionFailed
        self.retry = retry
        self.retriesExhausted = retriesExhausted
        self.startSync = startSync
        self.syncSucceeded = syncSucceeded
        self.syncFailed = syncFailed
        self.peripheralDisconnected = peripheralDisconnected
        self.resetRadio = resetRadio
        self.powerDown = powerDown
    }
}

public extension BLERuntimeHandlers {
    static let noop = Self()
}

public struct ScaleRuntimeHandlers: Sendable {
    public var footTap: @Sendable () async throws -> Void
    public var hardwareReady: @Sendable () async throws -> Void
    public var zeroAchieved: @Sendable () async throws -> Void
    public var weightLocked: @Sendable (Double) async throws -> Void
    public var userSteppedOffEarly: @Sendable () async throws -> Void
    public var startBIA: @Sendable () async throws -> Void
    public var biaComplete: @Sendable (BodyMetrics) async throws -> Void
    public var bareFeetRequiredError: @Sendable () async throws -> Void
    public var syncData: @Sendable (ScalePayload) async throws -> Void
    public var hardwareFault: @Sendable () async throws -> Void

    public init(
        footTap: @escaping @Sendable () async throws -> Void = {},
        hardwareReady: @escaping @Sendable () async throws -> Void = {},
        zeroAchieved: @escaping @Sendable () async throws -> Void = {},
        weightLocked: @escaping @Sendable (Double) async throws -> Void = { _ in },
        userSteppedOffEarly: @escaping @Sendable () async throws -> Void = {},
        startBIA: @escaping @Sendable () async throws -> Void = {},
        biaComplete: @escaping @Sendable (BodyMetrics) async throws -> Void = { _ in },
        bareFeetRequiredError: @escaping @Sendable () async throws -> Void = {},
        syncData: @escaping @Sendable (ScalePayload) async throws -> Void = { _ in },
        hardwareFault: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.footTap = footTap
        self.hardwareReady = hardwareReady
        self.zeroAchieved = zeroAchieved
        self.weightLocked = weightLocked
        self.userSteppedOffEarly = userSteppedOffEarly
        self.startBIA = startBIA
        self.biaComplete = biaComplete
        self.bareFeetRequiredError = bareFeetRequiredError
        self.syncData = syncData
        self.hardwareFault = hardwareFault
    }
}

public extension ScaleRuntimeHandlers {
    static let noop = Self()
}

public extension BLEClient {
    static func runtime(
        initialContext: @escaping @Sendable () -> BLEContext = { .init() },
        handlers: BLERuntimeHandlers
    ) -> Self {
        .fromRuntime(
            .init(
                initialContext: initialContext,
                powerOnTransition: { context in
                    try await handlers.powerOn()
                    return context
                },
                radioReadyTransition: { context in
                    try await handlers.radioReady()
                    return context
                },
                deviceDiscoveredDeviceBLEDeviceTransition: { context, device in
                    try await handlers.deviceDiscovered(device)
                    return context
                },
                scanTimeoutTransition: { context in
                    try await handlers.scanTimeout()
                    return context
                },
                connectionEstablishedTransition: { context in
                    try await handlers.connectionEstablished()
                    return context
                },
                connectionFailedReasonStringTransition: { context, reason in
                    try await handlers.connectionFailed(reason)
                    return context
                },
                retryTransition: { context in
                    try await handlers.retry()
                    return context
                },
                retriesExhaustedTransition: { context in
                    try await handlers.retriesExhausted()
                    return context
                },
                startSyncPayloadScalePayloadTransition: { context, payload in
                    try await handlers.startSync(payload)
                    return context
                },
                syncSucceededTransition: { context in
                    try await handlers.syncSucceeded()
                    return context
                },
                syncFailedReasonStringTransition: { context, reason in
                    try await handlers.syncFailed(reason)
                    return context
                },
                peripheralDisconnectedTransition: { context in
                    try await handlers.peripheralDisconnected()
                    return context
                },
                resetRadioTransition: { context in
                    try await handlers.resetRadio()
                    return context
                },
                powerDownTransition: { context in
                    try await handlers.powerDown()
                    return context
                }
            )
        )
    }

    static var noop: Self {
        .runtime(handlers: .noop)
    }
}

public extension ScaleClient {
    static func runtime(
        initialContext: @escaping @Sendable () -> ScaleContext = { .init() },
        handlers: ScaleRuntimeHandlers
    ) -> Self {
        .fromRuntime(
            .init(
                initialContext: initialContext,
                footTapTransition: { context in
                    try await handlers.footTap()
                    return context
                },
                hardwareReadyTransition: { context in
                    try await handlers.hardwareReady()
                    return context
                },
                zeroAchievedTransition: { context in
                    try await handlers.zeroAchieved()
                    return context
                },
                weightLockedWeightDoubleTransition: { context, weight in
                    try await handlers.weightLocked(weight)
                    return context
                },
                userSteppedOffEarlyTransition: { context in
                    try await handlers.userSteppedOffEarly()
                    return context
                },
                startBIATransition: { context in
                    try await handlers.startBIA()
                    return context
                },
                biaCompleteMetricsBodyMetricsTransition: { context, metrics in
                    try await handlers.biaComplete(metrics)
                    return context
                },
                bareFeetRequiredErrorTransition: { context in
                    try await handlers.bareFeetRequiredError()
                    return context
                },
                syncDataPayloadScalePayloadTransition: { context, payload in
                    try await handlers.syncData(payload)
                    return context
                },
                hardwareFaultTransition: { context in
                    try await handlers.hardwareFault()
                    return context
                }
            )
        )
    }

    static var noop: Self {
        .runtime(handlers: .noop)
    }
}

public struct BluetoohScaleSystem: Sendable {
    public var bleClient: BLEClient
    public var scaleClient: ScaleClient

    public init(bleClient: BLEClient, scaleClient: ScaleClient) {
        self.bleClient = bleClient
        self.scaleClient = scaleClient
    }

    public static func runtime(
        bleHandlers: BLERuntimeHandlers,
        scaleHandlers: ScaleRuntimeHandlers
    ) -> Self {
        Self(
            bleClient: .runtime(handlers: bleHandlers),
            scaleClient: .runtime(handlers: scaleHandlers)
        )
    }

    public static var noop: Self {
        .runtime(bleHandlers: .noop, scaleHandlers: .noop)
    }

    public func makeOrchestrator() -> ScaleOrchestrator {
        ScaleOrchestrator(
            initialState: ScaleState(self.scaleClient.makeScale()),
            makeBLEState: { BLEState(self.bleClient.makeBLE()) }
        )
    }
}

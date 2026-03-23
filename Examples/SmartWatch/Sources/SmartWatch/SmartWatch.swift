import Foundation

// MARK: - Device Discovery

/// A discovered BLE peripheral representing the watch.
public struct BLEDevice: Sendable, Equatable {
    public var identifier: UUID
    public var name: String

    public init(identifier: UUID = UUID(), name: String) {
        self.identifier = identifier
        self.name = name
    }
}

// MARK: - Context Types

/// Mutable state threaded through every BLE transition.
public struct WatchBLEContext: Sendable {
    public var maxRetries: Int
    public var retryCount: Int
    public var connectedDevice: BLEDevice?

    public init(
        maxRetries: Int = 5,
        retryCount: Int = 0,
        connectedDevice: BLEDevice? = nil
    ) {
        self.maxRetries = maxRetries
        self.retryCount = retryCount
        self.connectedDevice = connectedDevice
    }
}

/// Mutable state threaded through every heart-rate transition.
public struct HeartRateContext: Sendable {
    public var readings: [HeartRateReading]
    public var sessionStartDate: Date?

    public init(
        readings: [HeartRateReading] = [],
        sessionStartDate: Date? = nil
    ) {
        self.readings = readings
        self.sessionStartDate = sessionStartDate
    }
}

// MARK: - Value Types

/// A single heart-rate sample captured during a measurement session.
public struct HeartRateReading: Sendable, Equatable {
    public var bpm: Int
    public var timestamp: Date

    public init(bpm: Int, timestamp: Date = Date()) {
        self.bpm = bpm
        self.timestamp = timestamp
    }
}

// MARK: - BLE Runtime Handlers

/// Side-effect hooks for every BLE transition. The default no-op does nothing.
public struct WatchBLERuntimeHandlers: Sendable {
    public var startScan: @Sendable () async throws -> Void
    public var watchDiscovered: @Sendable (BLEDevice) async throws -> Void
    public var scanTimeout: @Sendable () async throws -> Void
    public var cancelScan: @Sendable () async throws -> Void
    public var connectionEstablished: @Sendable () async throws -> Void
    public var connectionFailed: @Sendable (String) async throws -> Void
    public var retry: @Sendable () async throws -> Void
    public var retriesExhausted: @Sendable () async throws -> Void
    public var peripheralDisconnected: @Sendable () async throws -> Void
    public var userDisconnected: @Sendable () async throws -> Void
    public var resetAndScan: @Sendable () async throws -> Void
    public var powerDown: @Sendable () async throws -> Void

    public init(
        startScan: @escaping @Sendable () async throws -> Void = {},
        watchDiscovered: @escaping @Sendable (BLEDevice) async throws -> Void = { _ in },
        scanTimeout: @escaping @Sendable () async throws -> Void = {},
        cancelScan: @escaping @Sendable () async throws -> Void = {},
        connectionEstablished: @escaping @Sendable () async throws -> Void = {},
        connectionFailed: @escaping @Sendable (String) async throws -> Void = { _ in },
        retry: @escaping @Sendable () async throws -> Void = {},
        retriesExhausted: @escaping @Sendable () async throws -> Void = {},
        peripheralDisconnected: @escaping @Sendable () async throws -> Void = {},
        userDisconnected: @escaping @Sendable () async throws -> Void = {},
        resetAndScan: @escaping @Sendable () async throws -> Void = {},
        powerDown: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.startScan = startScan
        self.watchDiscovered = watchDiscovered
        self.scanTimeout = scanTimeout
        self.cancelScan = cancelScan
        self.connectionEstablished = connectionEstablished
        self.connectionFailed = connectionFailed
        self.retry = retry
        self.retriesExhausted = retriesExhausted
        self.peripheralDisconnected = peripheralDisconnected
        self.userDisconnected = userDisconnected
        self.resetAndScan = resetAndScan
        self.powerDown = powerDown
    }
}

public extension WatchBLERuntimeHandlers {
    static let noop = Self()
}

// MARK: - Heart Rate Runtime Handlers

/// Side-effect hooks for every heart-rate transition. The default no-op does nothing.
public struct HeartRateRuntimeHandlers: Sendable {
    public var activate: @Sendable () async throws -> Void
    public var sensorReady: @Sendable () async throws -> Void
    public var sensorFailed: @Sendable (String) async throws -> Void
    public var startMeasurement: @Sendable () async throws -> Void
    public var measurementComplete: @Sendable (Int) async throws -> Void
    public var sensorContactLost: @Sendable () async throws -> Void
    public var sensorContactRestored: @Sendable () async throws -> Void
    public var contactTimeout: @Sendable () async throws -> Void
    public var reset: @Sendable () async throws -> Void
    public var deactivate: @Sendable () async throws -> Void

    public init(
        activate: @escaping @Sendable () async throws -> Void = {},
        sensorReady: @escaping @Sendable () async throws -> Void = {},
        sensorFailed: @escaping @Sendable (String) async throws -> Void = { _ in },
        startMeasurement: @escaping @Sendable () async throws -> Void = {},
        measurementComplete: @escaping @Sendable (Int) async throws -> Void = { _ in },
        sensorContactLost: @escaping @Sendable () async throws -> Void = {},
        sensorContactRestored: @escaping @Sendable () async throws -> Void = {},
        contactTimeout: @escaping @Sendable () async throws -> Void = {},
        reset: @escaping @Sendable () async throws -> Void = {},
        deactivate: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.activate = activate
        self.sensorReady = sensorReady
        self.sensorFailed = sensorFailed
        self.startMeasurement = startMeasurement
        self.measurementComplete = measurementComplete
        self.sensorContactLost = sensorContactLost
        self.sensorContactRestored = sensorContactRestored
        self.contactTimeout = contactTimeout
        self.reset = reset
        self.deactivate = deactivate
    }
}

public extension HeartRateRuntimeHandlers {
    static let noop = Self()
}

// MARK: - BLEClient Convenience

public extension BLEClient {
    static func runtime(
        initialContext: @escaping @Sendable () -> WatchBLEContext = { .init() },
        handlers: WatchBLERuntimeHandlers
    ) -> Self {
        .fromRuntime(
            .init(
                initialContext: initialContext,
                startScanTransition: { ctx in
                    try await handlers.startScan()
                    return ctx
                },
                watchDiscoveredBLEDeviceTransition: { ctx, device in
                    try await handlers.watchDiscovered(device)
                    var c = ctx; c.connectedDevice = device; return c
                },
                scanTimeoutTransition: { ctx in
                    try await handlers.scanTimeout()
                    return ctx
                },
                cancelScanTransition: { ctx in
                    try await handlers.cancelScan()
                    return ctx
                },
                connectionEstablishedTransition: { ctx in
                    try await handlers.connectionEstablished()
                    var c = ctx; c.retryCount = 0; return c
                },
                connectionFailedStringTransition: { ctx, reason in
                    try await handlers.connectionFailed(reason)
                    var c = ctx; c.retryCount += 1; return c
                },
                retryTransition: { ctx in
                    try await handlers.retry()
                    return ctx
                },
                retriesExhaustedTransition: { ctx in
                    try await handlers.retriesExhausted()
                    return ctx
                },
                peripheralDisconnectedTransition: { ctx in
                    try await handlers.peripheralDisconnected()
                    var c = ctx; c.connectedDevice = nil; return c
                },
                userDisconnectedTransition: { ctx in
                    try await handlers.userDisconnected()
                    var c = ctx; c.connectedDevice = nil; return c
                },
                resetAndScanTransition: { ctx in
                    try await handlers.resetAndScan()
                    return ctx
                },
                powerDownTransition: { ctx in
                    try await handlers.powerDown()
                    return ctx
                }
            )
        )
    }

    static var noop: Self { .runtime(handlers: .noop) }
}

// MARK: - HeartRateClient Convenience

public extension HeartRateClient {
    static func runtime(
        initialContext: @escaping @Sendable () -> HeartRateContext = { .init() },
        handlers: HeartRateRuntimeHandlers
    ) -> Self {
        .fromRuntime(
            .init(
                initialContext: initialContext,
                activateTransition: { ctx in
                    try await handlers.activate()
                    var c = ctx; c.sessionStartDate = Date(); return c
                },
                sensorReadyTransition: { ctx in
                    try await handlers.sensorReady()
                    return ctx
                },
                sensorFailedStringTransition: { ctx, reason in
                    try await handlers.sensorFailed(reason)
                    return ctx
                },
                startMeasurementTransition: { ctx in
                    try await handlers.startMeasurement()
                    return ctx
                },
                measurementCompleteIntTransition: { ctx, bpm in
                    try await handlers.measurementComplete(bpm)
                    var c = ctx; c.readings.append(HeartRateReading(bpm: bpm)); return c
                },
                sensorContactLostTransition: { ctx in
                    try await handlers.sensorContactLost()
                    return ctx
                },
                sensorContactRestoredTransition: { ctx in
                    try await handlers.sensorContactRestored()
                    return ctx
                },
                contactTimeoutTransition: { ctx in
                    try await handlers.contactTimeout()
                    return ctx
                },
                resetTransition: { ctx in
                    try await handlers.reset()
                    var c = ctx
                    c.readings = []
                    c.sessionStartDate = nil
                    return c
                },
                deactivateTransition: { ctx in
                    try await handlers.deactivate()
                    return ctx
                }
            )
        )
    }

    static var noop: Self { .runtime(handlers: .noop) }
}

// MARK: - WatchAudioClient Convenience

public extension WatchAudioClient {
    static var noop: Self {
        .fromRuntime(
            .init(
                initialContext: { .init() },
                initializeTransition: { ctx in ctx },
                audioReadyTransition: { ctx in ctx },
                audioFailedTransition: { ctx in ctx },
                playStringTransition: { ctx, _ in ctx },
                pauseTransition: { ctx in ctx },
                stopTransition: { ctx in ctx },
                trackEndedTransition: { ctx in ctx },
                adjustVolumeFloatTransition: { ctx, _ in ctx },
                resumeTransition: { ctx in ctx },
                resetTransition: { ctx in ctx },
                shutdownTransition: { ctx in ctx }
            )
        )
    }
}

// MARK: - System

/// Assembles the three clients and provides the root state machine factory.
public struct SmartWatchSystem: Sendable {
    public var bleClient: BLEClient
    public var heartRateClient: HeartRateClient
    public var audioClient: WatchAudioClient

    public init(
        bleClient: BLEClient,
        heartRateClient: HeartRateClient,
        audioClient: WatchAudioClient = .noop
    ) {
        self.bleClient = bleClient
        self.heartRateClient = heartRateClient
        self.audioClient = audioClient
    }

    public static func runtime(
        bleHandlers: WatchBLERuntimeHandlers,
        heartRateHandlers: HeartRateRuntimeHandlers
    ) -> Self {
        Self(
            bleClient: .runtime(handlers: bleHandlers),
            heartRateClient: .runtime(handlers: heartRateHandlers)
        )
    }

    public static var noop: Self {
        .runtime(bleHandlers: .noop, heartRateHandlers: .noop)
    }

    /// Creates the initial `HeartRateState` with BLE embedded, ready for a monitoring session.
    public func makeHeartRateState() -> HeartRateState {
        HeartRateState(heartRateClient.makeHeartRate { [bleClient] in
            BLEState(bleClient.makeWatchBLE())
        })
    }
}

// MARK: - Coordinator

/// Drives a complete heart-rate monitoring session over BLE.
///
/// The coordinator owns the `WatchBLEBridge` that is shared with `BLEClient.makeLive(bridge:)`.
/// This lets it both drive BLE state transitions (via `HeartRateState` forwarding methods)
/// and await low-level hardware events (peripheral discovery, HR notifications) directly.
///
/// Usage:
/// ```swift
/// let coordinator = WatchCoordinator()
/// let readings = try await coordinator.measureHeartRate(samples: 5)
/// ```
public actor WatchCoordinator {
    private let bridge: WatchBLEBridge
    private let system: SmartWatchSystem

    public init(bridge: WatchBLEBridge = WatchBLEBridge()) {
        self.bridge = bridge
        self.system = SmartWatchSystem(
            bleClient: BLEClient.makeLive(bridge: bridge),
            heartRateClient: HeartRateClient.makeLive(bridge: bridge)
        )
    }

    /// Runs a complete monitoring session: BLE connect → N readings → disconnect.
    ///
    /// Each call creates a fresh state machine and performs a full session.
    /// - Parameter samples: Number of consecutive heart-rate measurements to take.
    /// - Returns: The collected readings in chronological order.
    @discardableResult
    public func measureHeartRate(samples: Int = 5) async throws -> [HeartRateReading] {
        var state = system.makeHeartRateState()

        // 1. Activate HR sensor; also spawns the BLE machine at Off.
        state = try await state.activate()

        // 2. Power on and start scanning — suspends until CBCentralManager reports .poweredOn.
        state = try await state.bleStartScan()

        // 3. Await the first discovered peripheral.
        let device = try await bridge.waitForWatch()

        // 4. Connect and discover the HR GATT service/characteristic.
        state = try await state.bleWatchDiscovered(device: device)
        state = try await state.bleConnectionEstablished()

        // 5. HR optical sensor has passed self-check.
        state = try await state.sensorReady()

        // 6. Take N consecutive measurements.
        for _ in 0..<samples {
            state = try await state.startMeasurement()
            // bridge.readHeartRate() suspends until the next GATT HR notification fires.
            let bpm = try await bridge.readHeartRate()
            state = try await state.measurementComplete(bpm: bpm)
        }

        // 7. Deactivate the HR sensor.
        state = try await state.deactivate()

        // 8. Power down the BLE connection.
        state = try await state.blePowerDown()
        _ = consume state

        return readings(from: bridge)
    }

    // MARK: - Private Helpers

    private func readings(from bridge: WatchBLEBridge) -> [HeartRateReading] {
        bridge.collectedReadings
    }
}


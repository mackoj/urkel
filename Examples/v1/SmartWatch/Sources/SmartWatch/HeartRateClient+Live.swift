import Foundation

// MARK: - HeartRateClient Live

public extension HeartRateClient {
    /// Creates the live heart-rate client using a shared bridge.
    ///
    /// The `bridge` is the same `WatchBLEBridge` shared with `BLEClient.makeLive(bridge:)`
    /// so HR notifications flow through the already-established BLE connection.
    static func makeLive(bridge: WatchBLEBridge) -> Self {
        .runtime(handlers: HeartRateRuntimeHandlers(
            activate: {
                // No additional hardware work needed; BLE is driven via the composed machine.
            },
            sensorReady: {
                // Optical sensor passed self-check; no action required.
            },
            measurementComplete: { _ in
                // Context update (appending the reading) is handled in the runtime() extension.
                // Real implementation: write to HealthKit, trigger haptic, etc.
            }
        ))
    }

    /// Default live value used by the dependency system.
    ///
    /// For coordinated sessions use `WatchCoordinator` which manages a shared bridge.
    static func makeLive() -> Self { .noop }
}

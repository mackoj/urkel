import CoreBluetooth
import Foundation

// MARK: - Domain Runtime Handlers

/// Domain-owned callbacks that connect platform behavior to generated transitions.
///
/// The generated code already provides typed states, transition methods, dependency wiring,
/// and runtime scaffolding. What remains app-specific is how Bluetooth APIs are invoked and
/// how external delegate events trigger transitions.
public struct BluetoohBlenderRuntimeHandlers: Sendable {
    public var startScan: @Sendable () async throws -> Void
    public var deviceFound: @Sendable (CBPeripheral) async throws -> Void
    public var timeout: @Sendable () async throws -> Void
    public var connectSuccess: @Sendable () async throws -> Void
    public var connectFail: @Sendable (Error) async throws -> Void
    public var disconnect: @Sendable () async throws -> Void

    public init(
        startScan: @escaping @Sendable () async throws -> Void,
        deviceFound: @escaping @Sendable (CBPeripheral) async throws -> Void,
        timeout: @escaping @Sendable () async throws -> Void,
        connectSuccess: @escaping @Sendable () async throws -> Void,
        connectFail: @escaping @Sendable (Error) async throws -> Void,
        disconnect: @escaping @Sendable () async throws -> Void
    ) {
        self.startScan = startScan
        self.deviceFound = deviceFound
        self.timeout = timeout
        self.connectSuccess = connectSuccess
        self.connectFail = connectFail
        self.disconnect = disconnect
    }
}

extension BluetoohBlenderRuntimeHandlers {
    /// A side-effect-free runtime useful for tests and previews.
    public static let noop = Self(
        startScan: {},
        deviceFound: { _ in },
        timeout: {},
        connectSuccess: {},
        connectFail: { _ in },
        disconnect: {}
    )
}

// MARK: - Client Assembly

extension BluetoohBlenderClient {
    /// Builds a client by adapting domain callbacks to generated transition hooks.
    ///
    /// This is where package code stays domain-specific:
    /// - drive `CBCentralManager` scanning/connection APIs
    /// - map delegate callbacks into transition calls
    /// - apply retry and timeout policy decisions
    public static func runtime(
        initialContext: @escaping @Sendable () -> BluetoohBlenderMachine.RuntimeContext = { .init() },
        handlers: BluetoohBlenderRuntimeHandlers
    ) -> Self {
        .fromRuntime(
            .init(
                initialContext: initialContext,
                startScanTransition: { context in
                    try await handlers.startScan()
                    return context
                },
                deviceFoundDeviceCBPeripheralTransition: { context, device in
                    try await handlers.deviceFound(device)
                    return context
                },
                timeoutTransition: { context in
                    try await handlers.timeout()
                    return context
                },
                connectSuccessTransition: { context in
                    try await handlers.connectSuccess()
                    return context
                },
                connectFailErrorErrorTransition: { context, error in
                    try await handlers.connectFail(error)
                    return context
                },
                disconnectTransition: { context in
                    try await handlers.disconnect()
                    return context
                }
            )
        )
    }

    /// Ready-to-use no-op behavior for tests and previews.
    public static var noop: Self {
        .runtime(handlers: .noop)
    }
}

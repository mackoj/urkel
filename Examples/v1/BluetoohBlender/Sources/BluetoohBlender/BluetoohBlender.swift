import CoreBluetooth
import Foundation

// MARK: - Domain Runtime Handlers

/// Domain-owned callbacks that connect platform behavior to generated transitions.
public struct BluetoohBlenderRuntimeHandlers: Sendable {
    public var startScan: @Sendable () async throws -> Void
    public var stopScan: @Sendable () async throws -> Void
    public var deviceFound: @Sendable (CBPeripheral) async throws -> Void
    public var timeout: @Sendable () async throws -> Void
    public var cancelConnect: @Sendable () async throws -> Void
    public var connectSuccess: @Sendable () async throws -> Void
    public var connectFail: @Sendable (Error) async throws -> Void

    public var startBlendSlow: @Sendable () async throws -> Void
    public var startBlendMedium: @Sendable () async throws -> Void
    public var startBlendHigh: @Sendable () async throws -> Void
    public var changeSpeedSlow: @Sendable () async throws -> Void
    public var changeSpeedMedium: @Sendable () async throws -> Void
    public var changeSpeedHigh: @Sendable () async throws -> Void
    public var pauseBlend: @Sendable () async throws -> Void
    public var resumeBlendSlow: @Sendable () async throws -> Void
    public var resumeBlendMedium: @Sendable () async throws -> Void
    public var resumeBlendHigh: @Sendable () async throws -> Void
    public var stopBlend: @Sendable () async throws -> Void

    public var removeBowl: @Sendable () async throws -> Void
    public var addBowl: @Sendable () async throws -> Void
    public var disconnect: @Sendable () async throws -> Void
    public var switchOff: @Sendable () async throws -> Void

    public init(
        startScan: @escaping @Sendable () async throws -> Void,
        stopScan: @escaping @Sendable () async throws -> Void,
        deviceFound: @escaping @Sendable (CBPeripheral) async throws -> Void,
        timeout: @escaping @Sendable () async throws -> Void,
        cancelConnect: @escaping @Sendable () async throws -> Void,
        connectSuccess: @escaping @Sendable () async throws -> Void,
        connectFail: @escaping @Sendable (Error) async throws -> Void,
        startBlendSlow: @escaping @Sendable () async throws -> Void,
        startBlendMedium: @escaping @Sendable () async throws -> Void,
        startBlendHigh: @escaping @Sendable () async throws -> Void,
        changeSpeedSlow: @escaping @Sendable () async throws -> Void,
        changeSpeedMedium: @escaping @Sendable () async throws -> Void,
        changeSpeedHigh: @escaping @Sendable () async throws -> Void,
        pauseBlend: @escaping @Sendable () async throws -> Void,
        resumeBlendSlow: @escaping @Sendable () async throws -> Void,
        resumeBlendMedium: @escaping @Sendable () async throws -> Void,
        resumeBlendHigh: @escaping @Sendable () async throws -> Void,
        stopBlend: @escaping @Sendable () async throws -> Void,
        removeBowl: @escaping @Sendable () async throws -> Void,
        addBowl: @escaping @Sendable () async throws -> Void,
        disconnect: @escaping @Sendable () async throws -> Void,
        switchOff: @escaping @Sendable () async throws -> Void
    ) {
        self.startScan = startScan
        self.stopScan = stopScan
        self.deviceFound = deviceFound
        self.timeout = timeout
        self.cancelConnect = cancelConnect
        self.connectSuccess = connectSuccess
        self.connectFail = connectFail
        self.startBlendSlow = startBlendSlow
        self.startBlendMedium = startBlendMedium
        self.startBlendHigh = startBlendHigh
        self.changeSpeedSlow = changeSpeedSlow
        self.changeSpeedMedium = changeSpeedMedium
        self.changeSpeedHigh = changeSpeedHigh
        self.pauseBlend = pauseBlend
        self.resumeBlendSlow = resumeBlendSlow
        self.resumeBlendMedium = resumeBlendMedium
        self.resumeBlendHigh = resumeBlendHigh
        self.stopBlend = stopBlend
        self.removeBowl = removeBowl
        self.addBowl = addBowl
        self.disconnect = disconnect
        self.switchOff = switchOff
    }
}

extension BluetoohBlenderRuntimeHandlers {
    /// A side-effect-free runtime useful for tests and previews.
    public static let noop = Self(
        startScan: {},
        stopScan: {},
        deviceFound: { _ in },
        timeout: {},
        cancelConnect: {},
        connectSuccess: {},
        connectFail: { _ in },
        startBlendSlow: {},
        startBlendMedium: {},
        startBlendHigh: {},
        changeSpeedSlow: {},
        changeSpeedMedium: {},
        changeSpeedHigh: {},
        pauseBlend: {},
        resumeBlendSlow: {},
        resumeBlendMedium: {},
        resumeBlendHigh: {},
        stopBlend: {},
        removeBowl: {},
        addBowl: {},
        disconnect: {},
        switchOff: {}
    )
}

// MARK: - Client Assembly

extension BluetoohBlenderClient {
    /// Builds a client by adapting domain callbacks to generated transition hooks.
    public static func runtime(
        initialContext: @escaping @Sendable () -> BluetoohBlenderStateRuntimeContext = { .init() },
        handlers: BluetoohBlenderRuntimeHandlers
    ) -> Self {
        .fromRuntime(
            .init(
                initialContext: initialContext,
                startScanTransition: { context in
                    try await handlers.startScan()
                    return context
                },
                stopScanTransition: { context in
                    try await handlers.stopScan()
                    return context
                },
                deviceFoundCBPeripheralTransition: { context, device in
                    try await handlers.deviceFound(device)
                    return context
                },
                timeoutTransition: { context in
                    try await handlers.timeout()
                    return context
                },
                cancelConnectTransition: { context in
                    try await handlers.cancelConnect()
                    return context
                },
                connectSuccessTransition: { context in
                    try await handlers.connectSuccess()
                    return context
                },
                connectFailErrorTransition: { context, error in
                    try await handlers.connectFail(error)
                    return context
                },
                startBlendSlowTransition: { context in
                    try await handlers.startBlendSlow()
                    return context
                },
                startBlendMediumTransition: { context in
                    try await handlers.startBlendMedium()
                    return context
                },
                startBlendHighTransition: { context in
                    try await handlers.startBlendHigh()
                    return context
                },
                changeSpeedMediumTransition: { context in
                    try await handlers.changeSpeedMedium()
                    return context
                },
                changeSpeedHighTransition: { context in
                    try await handlers.changeSpeedHigh()
                    return context
                },
                changeSpeedSlowTransition: { context in
                    try await handlers.changeSpeedSlow()
                    return context
                },
                pauseBlendTransition: { context in
                    try await handlers.pauseBlend()
                    return context
                },
                resumeBlendSlowTransition: { context in
                    try await handlers.resumeBlendSlow()
                    return context
                },
                resumeBlendMediumTransition: { context in
                    try await handlers.resumeBlendMedium()
                    return context
                },
                resumeBlendHighTransition: { context in
                    try await handlers.resumeBlendHigh()
                    return context
                },
                stopBlendTransition: { context in
                    try await handlers.stopBlend()
                    return context
                },
                removeBowlTransition: { context in
                    try await handlers.removeBowl()
                    return context
                },
                switchOffTransition: { context in
                    try await handlers.switchOff()
                    return context
                },
                addBowlTransition: { context in
                    try await handlers.addBowl()
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

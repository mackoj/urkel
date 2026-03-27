import CoreBluetooth
import Dependencies

// MARK: - BluetoohBlender Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct BluetoohBlenderClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> BluetoohBlenderStateRuntimeContext
    typealias StartScanTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias StopScanTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias DeviceFoundCBPeripheralTransition = @Sendable (BluetoohBlenderStateRuntimeContext, CBPeripheral) async throws -> BluetoohBlenderStateRuntimeContext
    typealias TimeoutTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias CancelConnectTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ConnectSuccessTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ConnectFailErrorTransition = @Sendable (BluetoohBlenderStateRuntimeContext, Error) async throws -> BluetoohBlenderStateRuntimeContext
    typealias StartBlendSlowTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias StartBlendMediumTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias StartBlendHighTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ChangeSpeedMediumTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ChangeSpeedHighTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ChangeSpeedSlowTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias PauseBlendTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ResumeBlendSlowTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ResumeBlendMediumTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias ResumeBlendHighTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias StopBlendTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias RemoveBowlTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias SwitchOffTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias AddBowlTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    typealias DisconnectTransition = @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    let initialContext: InitialContextBuilder
    let startScanTransition: StartScanTransition
    let stopScanTransition: StopScanTransition
    let deviceFoundCBPeripheralTransition: DeviceFoundCBPeripheralTransition
    let timeoutTransition: TimeoutTransition
    let cancelConnectTransition: CancelConnectTransition
    let connectSuccessTransition: ConnectSuccessTransition
    let connectFailErrorTransition: ConnectFailErrorTransition
    let startBlendSlowTransition: StartBlendSlowTransition
    let startBlendMediumTransition: StartBlendMediumTransition
    let startBlendHighTransition: StartBlendHighTransition
    let changeSpeedMediumTransition: ChangeSpeedMediumTransition
    let changeSpeedHighTransition: ChangeSpeedHighTransition
    let changeSpeedSlowTransition: ChangeSpeedSlowTransition
    let pauseBlendTransition: PauseBlendTransition
    let resumeBlendSlowTransition: ResumeBlendSlowTransition
    let resumeBlendMediumTransition: ResumeBlendMediumTransition
    let resumeBlendHighTransition: ResumeBlendHighTransition
    let stopBlendTransition: StopBlendTransition
    let removeBowlTransition: RemoveBowlTransition
    let switchOffTransition: SwitchOffTransition
    let addBowlTransition: AddBowlTransition
    let disconnectTransition: DisconnectTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        startScanTransition: @escaping StartScanTransition,
        stopScanTransition: @escaping StopScanTransition,
        deviceFoundCBPeripheralTransition: @escaping DeviceFoundCBPeripheralTransition,
        timeoutTransition: @escaping TimeoutTransition,
        cancelConnectTransition: @escaping CancelConnectTransition,
        connectSuccessTransition: @escaping ConnectSuccessTransition,
        connectFailErrorTransition: @escaping ConnectFailErrorTransition,
        startBlendSlowTransition: @escaping StartBlendSlowTransition,
        startBlendMediumTransition: @escaping StartBlendMediumTransition,
        startBlendHighTransition: @escaping StartBlendHighTransition,
        changeSpeedMediumTransition: @escaping ChangeSpeedMediumTransition,
        changeSpeedHighTransition: @escaping ChangeSpeedHighTransition,
        changeSpeedSlowTransition: @escaping ChangeSpeedSlowTransition,
        pauseBlendTransition: @escaping PauseBlendTransition,
        resumeBlendSlowTransition: @escaping ResumeBlendSlowTransition,
        resumeBlendMediumTransition: @escaping ResumeBlendMediumTransition,
        resumeBlendHighTransition: @escaping ResumeBlendHighTransition,
        stopBlendTransition: @escaping StopBlendTransition,
        removeBowlTransition: @escaping RemoveBowlTransition,
        switchOffTransition: @escaping SwitchOffTransition,
        addBowlTransition: @escaping AddBowlTransition,
        disconnectTransition: @escaping DisconnectTransition
    ) {
        self.initialContext = initialContext
        self.startScanTransition = startScanTransition
        self.stopScanTransition = stopScanTransition
        self.deviceFoundCBPeripheralTransition = deviceFoundCBPeripheralTransition
        self.timeoutTransition = timeoutTransition
        self.cancelConnectTransition = cancelConnectTransition
        self.connectSuccessTransition = connectSuccessTransition
        self.connectFailErrorTransition = connectFailErrorTransition
        self.startBlendSlowTransition = startBlendSlowTransition
        self.startBlendMediumTransition = startBlendMediumTransition
        self.startBlendHighTransition = startBlendHighTransition
        self.changeSpeedMediumTransition = changeSpeedMediumTransition
        self.changeSpeedHighTransition = changeSpeedHighTransition
        self.changeSpeedSlowTransition = changeSpeedSlowTransition
        self.pauseBlendTransition = pauseBlendTransition
        self.resumeBlendSlowTransition = resumeBlendSlowTransition
        self.resumeBlendMediumTransition = resumeBlendMediumTransition
        self.resumeBlendHighTransition = resumeBlendHighTransition
        self.stopBlendTransition = stopBlendTransition
        self.removeBowlTransition = removeBowlTransition
        self.switchOffTransition = switchOffTransition
        self.addBowlTransition = addBowlTransition
        self.disconnectTransition = disconnectTransition
    }
}

extension BluetoohBlenderClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: BluetoohBlenderClientRuntime) -> Self {
        Self(
            makeBlender: {
                let context = runtime.initialContext()
                return BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>(
                    internalContext: context,
                _startScan: runtime.startScanTransition,
                _stopScan: runtime.stopScanTransition,
                _deviceFoundCBPeripheral: runtime.deviceFoundCBPeripheralTransition,
                _timeout: runtime.timeoutTransition,
                _cancelConnect: runtime.cancelConnectTransition,
                _connectSuccess: runtime.connectSuccessTransition,
                _connectFailError: runtime.connectFailErrorTransition,
                _startBlendSlow: runtime.startBlendSlowTransition,
                _startBlendMedium: runtime.startBlendMediumTransition,
                _startBlendHigh: runtime.startBlendHighTransition,
                _changeSpeedMedium: runtime.changeSpeedMediumTransition,
                _changeSpeedHigh: runtime.changeSpeedHighTransition,
                _changeSpeedSlow: runtime.changeSpeedSlowTransition,
                _pauseBlend: runtime.pauseBlendTransition,
                _resumeBlendSlow: runtime.resumeBlendSlowTransition,
                _resumeBlendMedium: runtime.resumeBlendMediumTransition,
                _resumeBlendHigh: runtime.resumeBlendHighTransition,
                _stopBlend: runtime.stopBlendTransition,
                _removeBowl: runtime.removeBowlTransition,
                _switchOff: runtime.switchOffTransition,
                _addBowl: runtime.addBowlTransition,
                _disconnect: runtime.disconnectTransition
                )
            }
        )
    }
}

// MARK: - BluetoohBlender Client

/// Dependency client entry point for constructing BluetoohBlender state machines.
public struct BluetoohBlenderClient: Sendable {
    public var makeBlender: @Sendable () -> BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>

    public init(makeBlender: @escaping @Sendable () -> BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>) {
        self.makeBlender = makeBlender
    }
}
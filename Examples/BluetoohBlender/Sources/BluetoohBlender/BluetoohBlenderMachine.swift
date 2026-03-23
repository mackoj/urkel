import CoreBluetooth
import Dependencies

// MARK: - BluetoohBlender Typestate Markers

public enum BluetoohBlenderStateDisconnected {}
public enum BluetoohBlenderStateScanning {}
public enum BluetoohBlenderStateConnecting {}
public enum BluetoohBlenderStateConnectedWithBowl {}
public enum BluetoohBlenderStateConnectedWithoutBowl {}
public enum BluetoohBlenderStateBlendSlow {}
public enum BluetoohBlenderStateBlendMedium {}
public enum BluetoohBlenderStateBlendHigh {}
public enum BluetoohBlenderStatePaused {}
public enum BluetoohBlenderStateError {}
public enum BluetoohBlenderStateTurnedOff {}
internal struct BluetoohBlenderStateRuntimeContext: Sendable {
    init() {}
}

// MARK: - BluetoohBlender State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct BluetoohBlenderMachine<State>: ~Copyable {
    private var internalContext: BluetoohBlenderStateRuntimeContext

    fileprivate let _startScan: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _stopScan: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _deviceFoundCBPeripheral: @Sendable (BluetoohBlenderStateRuntimeContext, CBPeripheral) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _timeout: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _cancelConnect: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _connectSuccess: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _connectFailError: @Sendable (BluetoohBlenderStateRuntimeContext, Error) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _startBlendSlow: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _startBlendMedium: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _startBlendHigh: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _changeSpeedMedium: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _changeSpeedHigh: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _changeSpeedSlow: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _pauseBlend: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _resumeBlendSlow: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _resumeBlendMedium: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _resumeBlendHigh: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _stopBlend: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _removeBowl: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _switchOff: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _addBowl: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    fileprivate let _disconnect: @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    internal init(
        internalContext: BluetoohBlenderStateRuntimeContext,
        _startScan: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _stopScan: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _deviceFoundCBPeripheral: @escaping @Sendable (BluetoohBlenderStateRuntimeContext, CBPeripheral) async throws -> BluetoohBlenderStateRuntimeContext,
        _timeout: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _cancelConnect: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _connectSuccess: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _connectFailError: @escaping @Sendable (BluetoohBlenderStateRuntimeContext, Error) async throws -> BluetoohBlenderStateRuntimeContext,
        _startBlendSlow: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _startBlendMedium: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _startBlendHigh: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _changeSpeedMedium: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _changeSpeedHigh: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _changeSpeedSlow: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _pauseBlend: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _resumeBlendSlow: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _resumeBlendMedium: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _resumeBlendHigh: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _stopBlend: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _removeBowl: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _switchOff: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _addBowl: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext,
        _disconnect: @escaping @Sendable (BluetoohBlenderStateRuntimeContext) async throws -> BluetoohBlenderStateRuntimeContext
    ) {
        self.internalContext = internalContext

        self._startScan = _startScan
        self._stopScan = _stopScan
        self._deviceFoundCBPeripheral = _deviceFoundCBPeripheral
        self._timeout = _timeout
        self._cancelConnect = _cancelConnect
        self._connectSuccess = _connectSuccess
        self._connectFailError = _connectFailError
        self._startBlendSlow = _startBlendSlow
        self._startBlendMedium = _startBlendMedium
        self._startBlendHigh = _startBlendHigh
        self._changeSpeedMedium = _changeSpeedMedium
        self._changeSpeedHigh = _changeSpeedHigh
        self._changeSpeedSlow = _changeSpeedSlow
        self._pauseBlend = _pauseBlend
        self._resumeBlendSlow = _resumeBlendSlow
        self._resumeBlendMedium = _resumeBlendMedium
        self._resumeBlendHigh = _resumeBlendHigh
        self._stopBlend = _stopBlend
        self._removeBowl = _removeBowl
        self._switchOff = _switchOff
        self._addBowl = _addBowl
        self._disconnect = _disconnect
    }

    /// Access the internal context while preserving borrowing semantics.
    internal borrowing func withInternalContext<R>(_ body: (borrowing BluetoohBlenderStateRuntimeContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - BluetoohBlender.Disconnected Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateDisconnected {
    /// Handles the `startScan` transition from Disconnected to Scanning.
    public consuming func startScan() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateScanning> {
        let nextContext = try await self._startScan(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateScanning>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Scanning Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateScanning {
    /// Handles the `stopScan` transition from Scanning to Disconnected.
    public consuming func stopScan() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateDisconnected> {
        let nextContext = try await self._stopScan(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `deviceFound` transition from Scanning to Connecting.
    public consuming func deviceFound(device: CBPeripheral) async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnecting> {
        let nextContext = try await self._deviceFoundCBPeripheral(self.internalContext, device)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnecting>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `timeout` transition from Scanning to Disconnected.
    public consuming func timeout() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateDisconnected> {
        let nextContext = try await self._timeout(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Connecting Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateConnecting {
    /// Handles the `cancelConnect` transition from Connecting to Disconnected.
    public consuming func cancelConnect() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateDisconnected> {
        let nextContext = try await self._cancelConnect(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `connectSuccess` transition from Connecting to ConnectedWithBowl.
    public consuming func connectSuccess() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl> {
        let nextContext = try await self._connectSuccess(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `connectFail` transition from Connecting to Error.
    public consuming func connectFail(error: Error) async throws -> BluetoohBlenderMachine<BluetoohBlenderStateError> {
        let nextContext = try await self._connectFailError(self.internalContext, error)
        return BluetoohBlenderMachine<BluetoohBlenderStateError>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.ConnectedWithBowl Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateConnectedWithBowl {
    /// Handles the `startBlendSlow` transition from ConnectedWithBowl to BlendSlow.
    public consuming func startBlendSlow() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow> {
        let nextContext = try await self._startBlendSlow(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `startBlendMedium` transition from ConnectedWithBowl to BlendMedium.
    public consuming func startBlendMedium() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium> {
        let nextContext = try await self._startBlendMedium(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `startBlendHigh` transition from ConnectedWithBowl to BlendHigh.
    public consuming func startBlendHigh() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh> {
        let nextContext = try await self._startBlendHigh(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `removeBowl` transition from ConnectedWithBowl to ConnectedWithoutBowl.
    public consuming func removeBowl() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithoutBowl> {
        let nextContext = try await self._removeBowl(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithoutBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `switchOff` transition from ConnectedWithBowl to TurnedOff.
    public consuming func switchOff() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff> {
        let nextContext = try await self._switchOff(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `disconnect` transition from ConnectedWithBowl to Disconnected.
    public consuming func disconnect() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateDisconnected> {
        let nextContext = try await self._disconnect(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.BlendSlow Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateBlendSlow {
    /// Handles the `changeSpeedMedium` transition from BlendSlow to BlendMedium.
    public consuming func changeSpeedMedium() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium> {
        let nextContext = try await self._changeSpeedMedium(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `changeSpeedHigh` transition from BlendSlow to BlendHigh.
    public consuming func changeSpeedHigh() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh> {
        let nextContext = try await self._changeSpeedHigh(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `pauseBlend` transition from BlendSlow to Paused.
    public consuming func pauseBlend() async throws -> BluetoohBlenderMachine<BluetoohBlenderStatePaused> {
        let nextContext = try await self._pauseBlend(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStatePaused>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from BlendSlow to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.BlendMedium Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateBlendMedium {
    /// Handles the `changeSpeedSlow` transition from BlendMedium to BlendSlow.
    public consuming func changeSpeedSlow() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow> {
        let nextContext = try await self._changeSpeedSlow(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `changeSpeedHigh` transition from BlendMedium to BlendHigh.
    public consuming func changeSpeedHigh() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh> {
        let nextContext = try await self._changeSpeedHigh(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `pauseBlend` transition from BlendMedium to Paused.
    public consuming func pauseBlend() async throws -> BluetoohBlenderMachine<BluetoohBlenderStatePaused> {
        let nextContext = try await self._pauseBlend(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStatePaused>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from BlendMedium to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.BlendHigh Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateBlendHigh {
    /// Handles the `changeSpeedSlow` transition from BlendHigh to BlendSlow.
    public consuming func changeSpeedSlow() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow> {
        let nextContext = try await self._changeSpeedSlow(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `changeSpeedMedium` transition from BlendHigh to BlendMedium.
    public consuming func changeSpeedMedium() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium> {
        let nextContext = try await self._changeSpeedMedium(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `pauseBlend` transition from BlendHigh to Paused.
    public consuming func pauseBlend() async throws -> BluetoohBlenderMachine<BluetoohBlenderStatePaused> {
        let nextContext = try await self._pauseBlend(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStatePaused>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from BlendHigh to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Paused Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStatePaused {
    /// Handles the `resumeBlendSlow` transition from Paused to BlendSlow.
    public consuming func resumeBlendSlow() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow> {
        let nextContext = try await self._resumeBlendSlow(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `resumeBlendMedium` transition from Paused to BlendMedium.
    public consuming func resumeBlendMedium() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium> {
        let nextContext = try await self._resumeBlendMedium(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `resumeBlendHigh` transition from Paused to BlendHigh.
    public consuming func resumeBlendHigh() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh> {
        let nextContext = try await self._resumeBlendHigh(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `stopBlend` transition from Paused to ConnectedWithBowl.
    public consuming func stopBlend() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl> {
        let nextContext = try await self._stopBlend(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.ConnectedWithoutBowl Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateConnectedWithoutBowl {
    /// Handles the `addBowl` transition from ConnectedWithoutBowl to ConnectedWithBowl.
    public consuming func addBowl() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl> {
        let nextContext = try await self._addBowl(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `disconnect` transition from ConnectedWithoutBowl to Disconnected.
    public consuming func disconnect() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateDisconnected> {
        let nextContext = try await self._disconnect(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }

    /// Handles the `switchOff` transition from ConnectedWithoutBowl to TurnedOff.
    public consuming func switchOff() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff> {
        let nextContext = try await self._switchOff(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender.Error Transitions

extension BluetoohBlenderMachine where State == BluetoohBlenderStateError {
    /// Handles the `switchOff` transition from Error to TurnedOff.
    public consuming func switchOff() async throws -> BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff> {
        let nextContext = try await self._switchOff(self.internalContext)
        return BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff>(
            internalContext: nextContext,
                _startScan: self._startScan,
                _stopScan: self._stopScan,
                _deviceFoundCBPeripheral: self._deviceFoundCBPeripheral,
                _timeout: self._timeout,
                _cancelConnect: self._cancelConnect,
                _connectSuccess: self._connectSuccess,
                _connectFailError: self._connectFailError,
                _startBlendSlow: self._startBlendSlow,
                _startBlendMedium: self._startBlendMedium,
                _startBlendHigh: self._startBlendHigh,
                _changeSpeedMedium: self._changeSpeedMedium,
                _changeSpeedHigh: self._changeSpeedHigh,
                _changeSpeedSlow: self._changeSpeedSlow,
                _pauseBlend: self._pauseBlend,
                _resumeBlendSlow: self._resumeBlendSlow,
                _resumeBlendMedium: self._resumeBlendMedium,
                _resumeBlendHigh: self._resumeBlendHigh,
                _stopBlend: self._stopBlend,
                _removeBowl: self._removeBowl,
                _switchOff: self._switchOff,
                _addBowl: self._addBowl,
                _disconnect: self._disconnect
        )
    }
}

// MARK: - BluetoohBlender Combined State

/// A runtime-friendly wrapper over all observer states.
public enum BluetoohBlenderState: ~Copyable {
    case disconnected(BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>)
    case scanning(BluetoohBlenderMachine<BluetoohBlenderStateScanning>)
    case connecting(BluetoohBlenderMachine<BluetoohBlenderStateConnecting>)
    case connectedWithBowl(BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>)
    case connectedWithoutBowl(BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithoutBowl>)
    case blendSlow(BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow>)
    case blendMedium(BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium>)
    case blendHigh(BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh>)
    case paused(BluetoohBlenderMachine<BluetoohBlenderStatePaused>)
    case error(BluetoohBlenderMachine<BluetoohBlenderStateError>)
    case turnedOff(BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff>)

    public init(_ machine: consuming BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>) {
        self = .disconnected(machine)
    }
}

extension BluetoohBlenderState {
    public borrowing func withDisconnected<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateDisconnected>) throws -> R) rethrows -> R? {
        switch self {
        case let .disconnected(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withScanning<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateScanning>) throws -> R) rethrows -> R? {
        switch self {
        case let .scanning(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withConnecting<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateConnecting>) throws -> R) rethrows -> R? {
        switch self {
        case let .connecting(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withConnectedWithBowl<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl>) throws -> R) rethrows -> R? {
        switch self {
        case let .connectedWithBowl(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withConnectedWithoutBowl<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithoutBowl>) throws -> R) rethrows -> R? {
        switch self {
        case let .connectedWithoutBowl(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withBlendSlow<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateBlendSlow>) throws -> R) rethrows -> R? {
        switch self {
        case let .blendSlow(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withBlendMedium<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateBlendMedium>) throws -> R) rethrows -> R? {
        switch self {
        case let .blendMedium(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withBlendHigh<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateBlendHigh>) throws -> R) rethrows -> R? {
        switch self {
        case let .blendHigh(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withPaused<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStatePaused>) throws -> R) rethrows -> R? {
        switch self {
        case let .paused(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withError<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateError>) throws -> R) rethrows -> R? {
        switch self {
        case let .error(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withTurnedOff<R>(_ body: (borrowing BluetoohBlenderMachine<BluetoohBlenderStateTurnedOff>) throws -> R) rethrows -> R? {
        switch self {
        case let .turnedOff(observer):
            return try body(observer)
        default:
            return nil
        }
    }


    /// Attempts the `startScan` transition from the current wrapper state.
    public consuming func startScan() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .scanning(try await observer.startScan())
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `stopScan` transition from the current wrapper state.
    public consuming func stopScan() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .disconnected(try await observer.stopScan())
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `deviceFound` transition from the current wrapper state.
    public consuming func deviceFound(device: CBPeripheral) async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .connecting(try await observer.deviceFound(device: device))
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `timeout` transition from the current wrapper state.
    public consuming func timeout() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .disconnected(try await observer.timeout())
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `cancelConnect` transition from the current wrapper state.
    public consuming func cancelConnect() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .disconnected(try await observer.cancelConnect())
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `connectSuccess` transition from the current wrapper state.
    public consuming func connectSuccess() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connectedWithBowl(try await observer.connectSuccess())
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `connectFail` transition from the current wrapper state.
    public consuming func connectFail(error: Error) async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .error(try await observer.connectFail(error: error))
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `startBlendSlow` transition from the current wrapper state.
    public consuming func startBlendSlow() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .blendSlow(try await observer.startBlendSlow())
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `startBlendMedium` transition from the current wrapper state.
    public consuming func startBlendMedium() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .blendMedium(try await observer.startBlendMedium())
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `startBlendHigh` transition from the current wrapper state.
    public consuming func startBlendHigh() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .blendHigh(try await observer.startBlendHigh())
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `changeSpeedMedium` transition from the current wrapper state.
    public consuming func changeSpeedMedium() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendMedium(try await observer.changeSpeedMedium())
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendMedium(try await observer.changeSpeedMedium())
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `changeSpeedHigh` transition from the current wrapper state.
    public consuming func changeSpeedHigh() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendHigh(try await observer.changeSpeedHigh())
    case let .blendMedium(observer):
        return .blendHigh(try await observer.changeSpeedHigh())
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `changeSpeedSlow` transition from the current wrapper state.
    public consuming func changeSpeedSlow() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendSlow(try await observer.changeSpeedSlow())
    case let .blendHigh(observer):
        return .blendSlow(try await observer.changeSpeedSlow())
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `pauseBlend` transition from the current wrapper state.
    public consuming func pauseBlend() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .paused(try await observer.pauseBlend())
    case let .blendMedium(observer):
        return .paused(try await observer.pauseBlend())
    case let .blendHigh(observer):
        return .paused(try await observer.pauseBlend())
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `resumeBlendSlow` transition from the current wrapper state.
    public consuming func resumeBlendSlow() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .blendSlow(try await observer.resumeBlendSlow())
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `resumeBlendMedium` transition from the current wrapper state.
    public consuming func resumeBlendMedium() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .blendMedium(try await observer.resumeBlendMedium())
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `resumeBlendHigh` transition from the current wrapper state.
    public consuming func resumeBlendHigh() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .blendHigh(try await observer.resumeBlendHigh())
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `stopBlend` transition from the current wrapper state.
    public consuming func stopBlend() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .connectedWithBowl(try await observer.stopBlend())
    case let .blendMedium(observer):
        return .connectedWithBowl(try await observer.stopBlend())
    case let .blendHigh(observer):
        return .connectedWithBowl(try await observer.stopBlend())
    case let .paused(observer):
        return .connectedWithBowl(try await observer.stopBlend())
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `removeBowl` transition from the current wrapper state.
    public consuming func removeBowl() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithoutBowl(try await observer.removeBowl())
    case let .connectedWithoutBowl(observer):
        return .connectedWithoutBowl(observer)
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `switchOff` transition from the current wrapper state.
    public consuming func switchOff() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .turnedOff(try await observer.switchOff())
    case let .connectedWithoutBowl(observer):
        return .turnedOff(try await observer.switchOff())
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .turnedOff(try await observer.switchOff())
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `addBowl` transition from the current wrapper state.
    public consuming func addBowl() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .connectedWithBowl(observer)
    case let .connectedWithoutBowl(observer):
        return .connectedWithBowl(try await observer.addBowl())
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }

    /// Attempts the `disconnect` transition from the current wrapper state.
    public consuming func disconnect() async throws -> Self {
        switch consume self {
    case let .disconnected(observer):
        return .disconnected(observer)
    case let .scanning(observer):
        return .scanning(observer)
    case let .connecting(observer):
        return .connecting(observer)
    case let .connectedWithBowl(observer):
        return .disconnected(try await observer.disconnect())
    case let .connectedWithoutBowl(observer):
        return .disconnected(try await observer.disconnect())
    case let .blendSlow(observer):
        return .blendSlow(observer)
    case let .blendMedium(observer):
        return .blendMedium(observer)
    case let .blendHigh(observer):
        return .blendHigh(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .turnedOff(observer):
        return .turnedOff(observer)
        }
    }
}
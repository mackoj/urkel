import Testing
import Foundation
@testable import BluetoohBlender

private actor RuntimeCallCounter {
    private(set) var startScan = 0
    private(set) var stopScan = 0
    private(set) var deviceFound = 0
    private(set) var timeout = 0
    private(set) var cancelConnect = 0
    private(set) var connectSuccess = 0
    private(set) var connectFail = 0
    private(set) var startBlendSlow = 0
    private(set) var startBlendMedium = 0
    private(set) var startBlendHigh = 0
    private(set) var changeSpeedSlow = 0
    private(set) var changeSpeedMedium = 0
    private(set) var changeSpeedHigh = 0
    private(set) var pauseBlend = 0
    private(set) var resumeBlendSlow = 0
    private(set) var resumeBlendMedium = 0
    private(set) var resumeBlendHigh = 0
    private(set) var stopBlend = 0
    private(set) var removeBowl = 0
    private(set) var addBowl = 0
    private(set) var disconnect = 0
    private(set) var switchOff = 0

    func markStartScan() { startScan += 1 }
    func markStopScan() { stopScan += 1 }
    func markDeviceFound() { deviceFound += 1 }
    func markTimeout() { timeout += 1 }
    func markCancelConnect() { cancelConnect += 1 }
    func markConnectSuccess() { connectSuccess += 1 }
    func markConnectFail() { connectFail += 1 }
    func markStartBlendSlow() { startBlendSlow += 1 }
    func markStartBlendMedium() { startBlendMedium += 1 }
    func markStartBlendHigh() { startBlendHigh += 1 }
    func markChangeSpeedSlow() { changeSpeedSlow += 1 }
    func markChangeSpeedMedium() { changeSpeedMedium += 1 }
    func markChangeSpeedHigh() { changeSpeedHigh += 1 }
    func markPauseBlend() { pauseBlend += 1 }
    func markResumeBlendSlow() { resumeBlendSlow += 1 }
    func markResumeBlendMedium() { resumeBlendMedium += 1 }
    func markResumeBlendHigh() { resumeBlendHigh += 1 }
    func markStopBlend() { stopBlend += 1 }
    func markRemoveBowl() { removeBowl += 1 }
    func markAddBowl() { addBowl += 1 }
    func markDisconnect() { disconnect += 1 }
    func markSwitchOff() { switchOff += 1 }

    func snapshot() -> [String: Int] {
        [
            "startScan": startScan,
            "stopScan": stopScan,
            "deviceFound": deviceFound,
            "timeout": timeout,
            "cancelConnect": cancelConnect,
            "connectSuccess": connectSuccess,
            "connectFail": connectFail,
            "startBlendSlow": startBlendSlow,
            "startBlendMedium": startBlendMedium,
            "startBlendHigh": startBlendHigh,
            "changeSpeedSlow": changeSpeedSlow,
            "changeSpeedMedium": changeSpeedMedium,
            "changeSpeedHigh": changeSpeedHigh,
            "pauseBlend": pauseBlend,
            "resumeBlendSlow": resumeBlendSlow,
            "resumeBlendMedium": resumeBlendMedium,
            "resumeBlendHigh": resumeBlendHigh,
            "stopBlend": stopBlend,
            "removeBowl": removeBowl,
            "addBowl": addBowl,
            "disconnect": disconnect,
            "switchOff": switchOff
        ]
    }
}

private struct TestConnectError: Error {}

private func makeHandlers(counter: RuntimeCallCounter) -> BluetoohBlenderRuntimeHandlers {
    .init(
        startScan: { await counter.markStartScan() },
        stopScan: { await counter.markStopScan() },
        deviceFound: { _ in await counter.markDeviceFound() },
        timeout: { await counter.markTimeout() },
        cancelConnect: { await counter.markCancelConnect() },
        connectSuccess: { await counter.markConnectSuccess() },
        connectFail: { _ in await counter.markConnectFail() },
        startBlendSlow: { await counter.markStartBlendSlow() },
        startBlendMedium: { await counter.markStartBlendMedium() },
        startBlendHigh: { await counter.markStartBlendHigh() },
        changeSpeedSlow: { await counter.markChangeSpeedSlow() },
        changeSpeedMedium: { await counter.markChangeSpeedMedium() },
        changeSpeedHigh: { await counter.markChangeSpeedHigh() },
        pauseBlend: { await counter.markPauseBlend() },
        resumeBlendSlow: { await counter.markResumeBlendSlow() },
        resumeBlendMedium: { await counter.markResumeBlendMedium() },
        resumeBlendHigh: { await counter.markResumeBlendHigh() },
        stopBlend: { await counter.markStopBlend() },
        removeBowl: { await counter.markRemoveBowl() },
        addBowl: { await counter.markAddBowl() },
        disconnect: { await counter.markDisconnect() },
        switchOff: { await counter.markSwitchOff() }
    )
}

private func makeConnectedWithBowlObserver(
    handlers: BluetoohBlenderRuntimeHandlers
) -> BluetoohBlenderMachine<BluetoohBlenderStateConnectedWithBowl> {
    .init(
        internalContext: .init(),
        _startScan: { context in try await handlers.startScan(); return context },
        _stopScan: { context in try await handlers.stopScan(); return context },
        _deviceFoundCBPeripheral: { context, device in try await handlers.deviceFound(device); return context },
        _timeout: { context in try await handlers.timeout(); return context },
        _cancelConnect: { context in try await handlers.cancelConnect(); return context },
        _connectSuccess: { context in try await handlers.connectSuccess(); return context },
        _connectFailError: { context, error in try await handlers.connectFail(error); return context },
        _startBlendSlow: { context in try await handlers.startBlendSlow(); return context },
        _startBlendMedium: { context in try await handlers.startBlendMedium(); return context },
        _startBlendHigh: { context in try await handlers.startBlendHigh(); return context },
        _changeSpeedMedium: { context in try await handlers.changeSpeedMedium(); return context },
        _changeSpeedHigh: { context in try await handlers.changeSpeedHigh(); return context },
        _changeSpeedSlow: { context in try await handlers.changeSpeedSlow(); return context },
        _pauseBlend: { context in try await handlers.pauseBlend(); return context },
        _resumeBlendSlow: { context in try await handlers.resumeBlendSlow(); return context },
        _resumeBlendMedium: { context in try await handlers.resumeBlendMedium(); return context },
        _resumeBlendHigh: { context in try await handlers.resumeBlendHigh(); return context },
        _stopBlend: { context in try await handlers.stopBlend(); return context },
        _removeBowl: { context in try await handlers.removeBowl(); return context },
        _switchOff: { context in try await handlers.switchOff(); return context },
        _addBowl: { context in try await handlers.addBowl(); return context },
        _disconnect: { context in try await handlers.disconnect(); return context }
    )
}

private func makeConnectingObserver(
    handlers: BluetoohBlenderRuntimeHandlers
) -> BluetoohBlenderMachine<BluetoohBlenderStateConnecting> {
    .init(
        internalContext: .init(),
        _startScan: { context in try await handlers.startScan(); return context },
        _stopScan: { context in try await handlers.stopScan(); return context },
        _deviceFoundCBPeripheral: { context, device in try await handlers.deviceFound(device); return context },
        _timeout: { context in try await handlers.timeout(); return context },
        _cancelConnect: { context in try await handlers.cancelConnect(); return context },
        _connectSuccess: { context in try await handlers.connectSuccess(); return context },
        _connectFailError: { context, error in try await handlers.connectFail(error); return context },
        _startBlendSlow: { context in try await handlers.startBlendSlow(); return context },
        _startBlendMedium: { context in try await handlers.startBlendMedium(); return context },
        _startBlendHigh: { context in try await handlers.startBlendHigh(); return context },
        _changeSpeedMedium: { context in try await handlers.changeSpeedMedium(); return context },
        _changeSpeedHigh: { context in try await handlers.changeSpeedHigh(); return context },
        _changeSpeedSlow: { context in try await handlers.changeSpeedSlow(); return context },
        _pauseBlend: { context in try await handlers.pauseBlend(); return context },
        _resumeBlendSlow: { context in try await handlers.resumeBlendSlow(); return context },
        _resumeBlendMedium: { context in try await handlers.resumeBlendMedium(); return context },
        _resumeBlendHigh: { context in try await handlers.resumeBlendHigh(); return context },
        _stopBlend: { context in try await handlers.stopBlend(); return context },
        _removeBowl: { context in try await handlers.removeBowl(); return context },
        _switchOff: { context in try await handlers.switchOff(); return context },
        _addBowl: { context in try await handlers.addBowl(); return context },
        _disconnect: { context in try await handlers.disconnect(); return context }
    )
}

@Suite("BluetoohBlender")
struct BluetoohBlenderTests {
    @Test("No-op runtime supports disconnected -> scanning -> disconnected flow")
    func noopFlowTransitions() async throws {
        let observer = BluetoohBlenderClient.noop.makeBlender()
        let state = BluetoohBlenderState(observer)

        let scanning = try await state.startScan()
        #expect(scanning.withScanning { _ in true } == true)

        let disconnected = try await scanning.stopScan()
        #expect(disconnected.withDisconnected { _ in true } == true)
    }

    @Test("Bowl can be removed/added while connected and blending requires bowl")
    func bowlPresenceAndBlendRules() async throws {
        let counter = RuntimeCallCounter()
        let handlers = makeHandlers(counter: counter)
        let client = BluetoohBlenderClient.runtime(handlers: handlers)
        var state = BluetoohBlenderState(client.makeBlender())

        state = try await state.startScan()
        #expect(state.withScanning { _ in true } == true)

        state = try await state.stopScan()
        #expect(state.withDisconnected { _ in true } == true)

        state = try await state.startScan()
        #expect(state.withScanning { _ in true } == true)

        state = .connecting(makeConnectingObserver(handlers: handlers))
        #expect(state.withConnecting { _ in true } == true)

        state = try await state.cancelConnect()
        #expect(state.withDisconnected { _ in true } == true)

        state = .connectedWithBowl(makeConnectedWithBowlObserver(handlers: handlers))
        #expect(state.withConnectedWithBowl { _ in true } == true)

        state = try await state.removeBowl()
        #expect(state.withConnectedWithoutBowl { _ in true } == true)

        state = try await state.startBlendSlow()
        #expect(state.withConnectedWithoutBowl { _ in true } == true)

        state = try await state.addBowl()
        #expect(state.withConnectedWithBowl { _ in true } == true)

        state = try await state.startBlendHigh()
        #expect(state.withBlendHigh { _ in true } == true)

        state = try await state.pauseBlend()
        #expect(state.withPaused { _ in true } == true)

        state = try await state.resumeBlendMedium()
        #expect(state.withBlendMedium { _ in true } == true)

        state = try await state.changeSpeedSlow()
        #expect(state.withBlendSlow { _ in true } == true)

        state = try await state.changeSpeedHigh()
        #expect(state.withBlendHigh { _ in true } == true)

        state = try await state.stopBlend()
        #expect(state.withConnectedWithBowl { _ in true } == true)

        state = try await state.switchOff()
        #expect(state.withTurnedOff { _ in true } == true)

        let counts = await counter.snapshot()
        #expect(counts["removeBowl"] == 1)
        #expect(counts["addBowl"] == 1)
        #expect(counts["startBlendSlow"] == 0)
        #expect(counts["startBlendHigh"] == 1)
        #expect(counts["pauseBlend"] == 1)
        #expect(counts["resumeBlendMedium"] == 1)
        #expect(counts["changeSpeedSlow"] == 1)
        #expect(counts["changeSpeedHigh"] == 1)
        #expect(counts["stopScan"] == 1)
        #expect(counts["cancelConnect"] == 1)
        #expect(counts["stopBlend"] == 1)
        #expect(counts["switchOff"] == 1)
    }

    @Test("Connect failure transitions to error and can switch off")
    func connectFailFlow() async throws {
        let counter = RuntimeCallCounter()
        let handlers = makeHandlers(counter: counter)
        _ = BluetoohBlenderClient.runtime(handlers: handlers)
        var state = BluetoohBlenderState.connecting(makeConnectingObserver(handlers: handlers))
        state = try await state.connectFail(error: TestConnectError())
        #expect(state.withError { _ in true } == true)

        state = try await state.switchOff()
        #expect(state.withTurnedOff { _ in true } == true)

        let counts = await counter.snapshot()
        #expect(counts["connectFail"] == 1)
        #expect(counts["switchOff"] == 1)
    }
}

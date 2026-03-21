import Testing
import Foundation
import CoreBluetooth
@testable import BluetoohBlender

private actor RuntimeCallCounter {
    private(set) var startScan = 0
    private(set) var deviceFound = 0
    private(set) var timeout = 0
    private(set) var connectSuccess = 0
    private(set) var connectFail = 0
    private(set) var blending = 0
    private(set) var finished = 0
    private(set) var removeBowl = 0
    private(set) var addBowl = 0
    private(set) var disconnect = 0

    func markStartScan() { startScan += 1 }
    func markDeviceFound() { deviceFound += 1 }
    func markTimeout() { timeout += 1 }
    func markConnectSuccess() { connectSuccess += 1 }
    func markConnectFail() { connectFail += 1 }
    func markBlending() { blending += 1 }
    func markFinished() { finished += 1 }
    func markRemoveBowl() { removeBowl += 1 }
    func markAddBowl() { addBowl += 1 }
    func markDisconnect() { disconnect += 1 }

    func snapshot() -> (
        startScan: Int,
        deviceFound: Int,
        timeout: Int,
        connectSuccess: Int,
        connectFail: Int,
        blending: Int,
        finished: Int,
        removeBowl: Int,
        addBowl: Int,
        disconnect: Int
    ) {
        (
            startScan,
            deviceFound,
            timeout,
            connectSuccess,
            connectFail,
            blending,
            finished,
            removeBowl,
            addBowl,
            disconnect
        )
    }
}

private func makeHandlers(counter: RuntimeCallCounter) -> BluetoohBlenderRuntimeHandlers {
    .init(
        startScan: { await counter.markStartScan() },
        deviceFound: { _ in await counter.markDeviceFound() },
        timeout: { await counter.markTimeout() },
        connectSuccess: { await counter.markConnectSuccess() },
        connectFail: { _ in await counter.markConnectFail() },
        blending: { await counter.markBlending() },
        finished: { await counter.markFinished() },
        removeBowl: { await counter.markRemoveBowl() },
        addBowl: { await counter.markAddBowl() },
        disconnect: { await counter.markDisconnect() }
    )
}

private func makeConnectedWithBowlObserver(
    handlers: BluetoohBlenderRuntimeHandlers
) -> BluetoohBlenderObserver<BluetoohBlenderMachine.ConnectedWithBowl> {
    .init(
        internalContext: .init(),
        _startScan: { context in
            try await handlers.startScan()
            return context
        },
        _deviceFoundDeviceCBPeripheral: { context, device in
            try await handlers.deviceFound(device)
            return context
        },
        _timeout: { context in
            try await handlers.timeout()
            return context
        },
        _connectSuccess: { context in
            try await handlers.connectSuccess()
            return context
        },
        _connectFailErrorError: { context, error in
            try await handlers.connectFail(error)
            return context
        },
        _blending: { context in
            try await handlers.blending()
            return context
        },
        _finished: { context in
            try await handlers.finished()
            return context
        },
        _removeBowl: { context in
            try await handlers.removeBowl()
            return context
        },
        _addBowl: { context in
            try await handlers.addBowl()
            return context
        },
        _disconnect: { context in
            try await handlers.disconnect()
            return context
        }
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

        let disconnected = try await scanning.timeout()
        #expect(disconnected.withDisconnected { _ in true } == true)
    }

    @Test("Runtime handlers are called for triggered transitions")
    func runtimeHandlersAreInvoked() async throws {
        let counter = RuntimeCallCounter()
        let client = BluetoohBlenderClient.runtime(handlers: makeHandlers(counter: counter))

        let observer = client.makeBlender()
        let scanning = try await observer.startScan()
        _ = try await scanning.timeout()

        let counts = await counter.snapshot()
        #expect(counts.startScan == 1)
        #expect(counts.timeout == 1)
        #expect(counts.deviceFound == 0)
        #expect(counts.connectSuccess == 0)
        #expect(counts.connectFail == 0)
        #expect(counts.blending == 0)
        #expect(counts.finished == 0)
        #expect(counts.removeBowl == 0)
        #expect(counts.addBowl == 0)
        #expect(counts.disconnect == 0)
    }

    @Test("Bowl can be removed and added back while connected")
    func bowlPresenceFlowInConnectedStates() async throws {
        let counter = RuntimeCallCounter()
        let handlers = makeHandlers(counter: counter)
        var state = BluetoohBlenderState.connectedWithBowl(makeConnectedWithBowlObserver(handlers: handlers))
        state = try await state.removeBowl()
        #expect(state.withConnectedWithoutBowl { _ in true } == true)
        state = try await state.addBowl()
        #expect(state.withConnectedWithBowl { _ in true } == true)

        let counts = await counter.snapshot()
        #expect(counts.removeBowl == 1)
        #expect(counts.addBowl == 1)
        #expect(counts.blending == 0)
        #expect(counts.finished == 0)
    }

    @Test("Blending requires bowl presence")
    func blendingRequiresConnectedWithBowl() async throws {
        let counter = RuntimeCallCounter()
        let handlers = makeHandlers(counter: counter)
        var state = BluetoohBlenderState.connectedWithBowl(makeConnectedWithBowlObserver(handlers: handlers))
        state = try await state.removeBowl()
        let sameState = try await state.blending()
        #expect(sameState.withConnectedWithoutBowl { _ in true } == true)

        let counts = await counter.snapshot()
        #expect(counts.blending == 0)
    }
}

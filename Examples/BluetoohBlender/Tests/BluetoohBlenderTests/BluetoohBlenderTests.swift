import Testing
import Foundation
@testable import BluetoohBlender

private actor RuntimeCallCounter {
    private(set) var startScan = 0
    private(set) var deviceFound = 0
    private(set) var timeout = 0
    private(set) var connectSuccess = 0
    private(set) var connectFail = 0
    private(set) var disconnect = 0

    func markStartScan() { startScan += 1 }
    func markDeviceFound() { deviceFound += 1 }
    func markTimeout() { timeout += 1 }
    func markConnectSuccess() { connectSuccess += 1 }
    func markConnectFail() { connectFail += 1 }
    func markDisconnect() { disconnect += 1 }

    func snapshot() -> (startScan: Int, deviceFound: Int, timeout: Int, connectSuccess: Int, connectFail: Int, disconnect: Int) {
        (startScan, deviceFound, timeout, connectSuccess, connectFail, disconnect)
    }
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
        let client = BluetoohBlenderClient.runtime(
            handlers: .init(
                startScan: { await counter.markStartScan() },
                deviceFound: { _ in await counter.markDeviceFound() },
                timeout: { await counter.markTimeout() },
                connectSuccess: { await counter.markConnectSuccess() },
                connectFail: { _ in await counter.markConnectFail() },
                disconnect: { await counter.markDisconnect() }
            )
        )

        let observer = client.makeBlender()
        let scanning = try await observer.startScan()
        _ = try await scanning.timeout()

        let counts = await counter.snapshot()
        #expect(counts.startScan == 1)
        #expect(counts.timeout == 1)
        #expect(counts.deviceFound == 0)
        #expect(counts.connectSuccess == 0)
        #expect(counts.connectFail == 0)
        #expect(counts.disconnect == 0)
    }
}

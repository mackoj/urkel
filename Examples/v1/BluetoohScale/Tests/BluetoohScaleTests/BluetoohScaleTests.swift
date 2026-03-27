import Foundation
import Testing
@testable import BluetoohScale

private final class SpawnCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    func snapshot() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private actor PayloadRecorder {
    private(set) var lockedWeights: [Double] = []
    private(set) var scalePayloads: [ScalePayload] = []
    private(set) var blePayloads: [ScalePayload] = []

    func recordLockedWeight(_ value: Double) {
        lockedWeights.append(value)
    }

    func recordScalePayload(_ payload: ScalePayload) {
        scalePayloads.append(payload)
    }

    func recordBLEPayload(_ payload: ScalePayload) {
        blePayloads.append(payload)
    }

    func snapshot() -> (weights: [Double], scale: [ScalePayload], ble: [ScalePayload]) {
        (lockedWeights, scalePayloads, blePayloads)
    }
}

@Suite("BluetoohScale")
struct BluetoohScaleTests {
    @Test("Scale flow measures metrics and powers down")
    func scaleFlow() async throws {
        var state = ScaleState(ScaleClient.noop.makeScale { BLEState(BLEClient.noop.makeBLE()) })

        state = try await state.footTap()
        state = try await state.hardwareReady()
        state = try await state.zeroAchieved()
        state = try await state.weightLocked(weight: 79.6)
        state = try await state.startBIA()

        let metrics = BodyMetrics(
            bodyFatPercentage: 18.4,
            bodyWaterPercentage: 56.2,
            muscleMassKg: 32.1
        )
        state = try await state.biaComplete(metrics: metrics)

        let payload = ScalePayload(
            vendor: .withings,
            weightKg: 79.6,
            metrics: metrics
        )
        state = try await state.syncData(payload: payload)

        #expect(state.withPowerDown { _ in true } == true)
    }

    @Test("Scale flow supports bare-feet fallback")
    func scaleFallbackFlow() async throws {
        var state = ScaleState(ScaleClient.noop.makeScale { BLEState(BLEClient.noop.makeBLE()) })

        state = try await state.footTap()
        state = try await state.hardwareReady()
        state = try await state.zeroAchieved()
        state = try await state.weightLocked(weight: 74.2)
        state = try await state.startBIA()
        state = try await state.bareFeetRequiredError()

        let payload = ScalePayload(
            vendor: .garmin,
            weightKg: 74.2,
            metrics: nil
        )
        state = try await state.syncData(payload: payload)

        #expect(state.withPowerDown { _ in true } == true)
    }

    @Test("BLE flow supports reconnect and sync retry")
    func bleReconnectFlow() async throws {
        var state = BLEState(BLEClient.noop.makeBLE())

        let device = BLEDevice(name: "Withings Body+")
        let payload = ScalePayload(vendor: .withings, weightKg: 81.0, metrics: nil)

        state = try await state.powerOn()
        state = try await state.radioReady()
        state = try await state.deviceDiscovered(device: device)
        state = try await state.connectionFailed(reason: "pairing timeout")
        state = try await state.retry()
        state = try await state.connectionEstablished()
        state = try await state.startSync(payload: payload)
        state = try await state.syncFailed(reason: "gatt disconnected")
        state = try await state.retry()
        state = try await state.connectionEstablished()
        state = try await state.powerDown()

        #expect(state.withPoweredDown { _ in true } == true)
    }

    @Test("BLE machine embeds in Scale observer after hardwareReady fork")
    func bleEmbeddedAfterFork() async throws {
        let counter = SpawnCounter()
        var state = ScaleState(ScaleClient.noop.makeScale {
            counter.increment()
            return BLEState(BLEClient.noop.makeBLE())
        })

        state = try await state.footTap()
        state = try await state.hardwareReady()  // BLE spawned here (once)
        state = try await state.zeroAchieved()   // BLE carried forward

        #expect(counter.snapshot() == 1)
        #expect(state.withWeighing { obs in obs._bleState != nil } == true)
    }

    @Test("Runtime handlers receive payloads")
    func runtimeHandlersCapturePayloads() async throws {
        let recorder = PayloadRecorder()

        let scaleClient = ScaleClient.runtime(
            handlers: .init(
                weightLocked: { weight in
                    await recorder.recordLockedWeight(weight)
                },
                syncData: { payload in
                    await recorder.recordScalePayload(payload)
                }
            )
        )

        let bleClient = BLEClient.runtime(
            handlers: .init(
                startSync: { payload in
                    await recorder.recordBLEPayload(payload)
                }
            )
        )

        let payload = ScalePayload(
            vendor: .garmin,
            weightKg: 88.8,
            metrics: nil
        )

        var scaleState = ScaleState(scaleClient.makeScale { BLEState(bleClient.makeBLE()) })
        scaleState = try await scaleState.footTap()
        scaleState = try await scaleState.hardwareReady()
        scaleState = try await scaleState.zeroAchieved()
        scaleState = try await scaleState.weightLocked(weight: 88.8)
        scaleState = try await scaleState.startBIA()
        scaleState = try await scaleState.bareFeetRequiredError()
        scaleState = try await scaleState.syncData(payload: payload)

        var bleState = BLEState(bleClient.makeBLE())
        bleState = try await bleState.powerOn()
        bleState = try await bleState.radioReady()
        bleState = try await bleState.deviceDiscovered(device: BLEDevice(name: "Garmin Index"))
        bleState = try await bleState.connectionEstablished()
        bleState = try await bleState.startSync(payload: payload)

        let snapshot = await recorder.snapshot()
        #expect(snapshot.weights == [88.8])
        #expect(snapshot.scale.count == 1)
        #expect(snapshot.scale.first?.vendor == .garmin)
        #expect(snapshot.ble.count == 1)
        #expect(snapshot.ble.first?.weightKg == 88.8)

        #expect(scaleState.withPowerDown { _ in true } == true)
        #expect(bleState.withSyncing { _ in true } == true)
    }
}

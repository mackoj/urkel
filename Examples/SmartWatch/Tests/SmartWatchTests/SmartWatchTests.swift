import Testing
@testable import SmartWatch

@Suite("SmartWatch")
struct SmartWatchTests {

    @Test("Noop system creates an initial HeartRate state")
    func noopSystemCreatesHeartRateState() async throws {
        let system = SmartWatchSystem.noop
        var state = system.makeHeartRateState()

        // Drive the full composed stack without any real hardware.
        // The typestate machine enforces the only valid sequence at compile time.
        state = try await state.activate()
        state = try await state.bleStartScan()
        state = try await state.bleWatchDiscovered(device: BLEDevice(name: "Test Watch"))
        state = try await state.bleConnectionEstablished()
        state = try await state.sensorReady()

        // Measure one heart-rate sample.
        state = try await state.startMeasurement()
        state = try await state.measurementComplete(bpm: 72)

        // Clean shutdown.
        state = try await state.deactivate()
        state = try await state.blePowerDown()
        _ = consume state
    }

    @Test("Noop WatchAudio client drives full playback lifecycle")
    func noopAudioClientDrivesPlayback() async throws {
        let client = WatchAudioClient.noop
        var audio = WatchAudioState(client.makePlayer())
        audio = try await audio.initialize()
        audio = try await audio.audioReady()
        audio = try await audio.play(trackId: "track-01.m4a")
        audio = try await audio.adjustVolume(level: 0.8)
        audio = try await audio.pause()
        audio = try await audio.resume()
        audio = try await audio.stop()
        audio = try await audio.shutdown()
        _ = consume audio
    }
}

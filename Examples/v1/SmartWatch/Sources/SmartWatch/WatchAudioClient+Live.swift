import AVFoundation
import Foundation

// MARK: - Audio Player State

/// Shared, actor-isolated audio state threaded through the WatchAudio machine.
private actor _AudioPlayerState {
    private var player: AVAudioPlayer?

    func play(trackId: String) throws {
        player?.stop()
        // In production: load from bundle or resolve a local URL.
        // guard let url = Bundle.main.url(forResource: trackId, withExtension: nil) else { return }
        // player = try AVAudioPlayer(contentsOf: url)
        // player?.play()
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func adjustVolume(_ level: Float) {
        player?.volume = max(0, min(1, level))
    }

    func tearDown() {
        player?.stop()
        player = nil
    }
}

// MARK: - WatchAudioClient Live

public extension WatchAudioClient {
    /// Creates the live AVFoundation-backed audio client.
    static func makeLive() -> Self {
        let audioState = _AudioPlayerState()

        return .fromRuntime(
            .init(
                initialContext: { .init() },
                initializeTransition: { ctx in
                    #if os(iOS)
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    #endif
                    return ctx
                },
                audioReadyTransition: { ctx in ctx },
                audioFailedTransition: { ctx in ctx },
                playStringTransition: { ctx, trackId in
                    try await audioState.play(trackId: trackId)
                    return ctx
                },
                pauseTransition: { ctx in
                    await audioState.pause()
                    return ctx
                },
                stopTransition: { ctx in
                    await audioState.stop()
                    return ctx
                },
                trackEndedTransition: { ctx in
                    await audioState.stop()
                    return ctx
                },
                adjustVolumeFloatTransition: { ctx, level in
                    await audioState.adjustVolume(level)
                    return ctx
                },
                resumeTransition: { ctx in
                    await audioState.resume()
                    return ctx
                },
                resetTransition: { ctx in
                    await audioState.tearDown()
                    #if os(iOS)
                    try? AVAudioSession.sharedInstance().setActive(false)
                    #endif
                    return ctx
                },
                shutdownTransition: { ctx in
                    await audioState.tearDown()
                    #if os(iOS)
                    try? AVAudioSession.sharedInstance().setActive(false)
                    #endif
                    return ctx
                }
            )
        )
    }
}

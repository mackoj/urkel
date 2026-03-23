import Foundation
import Dependencies

// MARK: - WatchAudio Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct WatchAudioClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> WatchAudioStateRuntimeContext
    typealias InitializeTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias AudioReadyTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias AudioFailedTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias PlayStringTransition = @Sendable (WatchAudioStateRuntimeContext, String) async throws -> WatchAudioStateRuntimeContext
    typealias PauseTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias StopTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias TrackEndedTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias AdjustVolumeFloatTransition = @Sendable (WatchAudioStateRuntimeContext, Float) async throws -> WatchAudioStateRuntimeContext
    typealias ResumeTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias ResetTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    typealias ShutdownTransition = @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    let initialContext: InitialContextBuilder
    let initializeTransition: InitializeTransition
    let audioReadyTransition: AudioReadyTransition
    let audioFailedTransition: AudioFailedTransition
    let playStringTransition: PlayStringTransition
    let pauseTransition: PauseTransition
    let stopTransition: StopTransition
    let trackEndedTransition: TrackEndedTransition
    let adjustVolumeFloatTransition: AdjustVolumeFloatTransition
    let resumeTransition: ResumeTransition
    let resetTransition: ResetTransition
    let shutdownTransition: ShutdownTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        initializeTransition: @escaping InitializeTransition,
        audioReadyTransition: @escaping AudioReadyTransition,
        audioFailedTransition: @escaping AudioFailedTransition,
        playStringTransition: @escaping PlayStringTransition,
        pauseTransition: @escaping PauseTransition,
        stopTransition: @escaping StopTransition,
        trackEndedTransition: @escaping TrackEndedTransition,
        adjustVolumeFloatTransition: @escaping AdjustVolumeFloatTransition,
        resumeTransition: @escaping ResumeTransition,
        resetTransition: @escaping ResetTransition,
        shutdownTransition: @escaping ShutdownTransition
    ) {
        self.initialContext = initialContext
        self.initializeTransition = initializeTransition
        self.audioReadyTransition = audioReadyTransition
        self.audioFailedTransition = audioFailedTransition
        self.playStringTransition = playStringTransition
        self.pauseTransition = pauseTransition
        self.stopTransition = stopTransition
        self.trackEndedTransition = trackEndedTransition
        self.adjustVolumeFloatTransition = adjustVolumeFloatTransition
        self.resumeTransition = resumeTransition
        self.resetTransition = resetTransition
        self.shutdownTransition = shutdownTransition
    }
}

extension WatchAudioClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: WatchAudioClientRuntime) -> Self {
        Self(
            makePlayer: {
                let context = runtime.initialContext()
                return WatchAudioMachine<WatchAudioStateOff>(
                    internalContext: context,
                _initialize: runtime.initializeTransition,
                _audioReady: runtime.audioReadyTransition,
                _audioFailed: runtime.audioFailedTransition,
                _playString: runtime.playStringTransition,
                _pause: runtime.pauseTransition,
                _stop: runtime.stopTransition,
                _trackEnded: runtime.trackEndedTransition,
                _adjustVolumeFloat: runtime.adjustVolumeFloatTransition,
                _resume: runtime.resumeTransition,
                _reset: runtime.resetTransition,
                _shutdown: runtime.shutdownTransition
                )
            }
        )
    }
}

// MARK: - WatchAudio Client

/// Dependency client entry point for constructing WatchAudio state machines.
public struct WatchAudioClient: Sendable {
    public var makePlayer: @Sendable () -> WatchAudioMachine<WatchAudioStateOff>

    public init(makePlayer: @escaping @Sendable () -> WatchAudioMachine<WatchAudioStateOff>) {
        self.makePlayer = makePlayer
    }
}
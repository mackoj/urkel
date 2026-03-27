import Foundation
import Dependencies

// MARK: - WatchAudio Typestate Markers

public enum WatchAudioStateOff {}
public enum WatchAudioStateInitializing {}
public enum WatchAudioStateIdle {}
public enum WatchAudioStatePlaying {}
public enum WatchAudioStatePaused {}
public enum WatchAudioStateError {}
public enum WatchAudioStateTerminated {}
internal struct WatchAudioStateRuntimeContext: Sendable {
    init() {}
}

// MARK: - WatchAudio State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct WatchAudioMachine<State>: ~Copyable {
    private var internalContext: WatchAudioStateRuntimeContext

    fileprivate let _initialize: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _audioReady: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _audioFailed: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _playString: @Sendable (WatchAudioStateRuntimeContext, String) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _pause: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _stop: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _trackEnded: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _adjustVolumeFloat: @Sendable (WatchAudioStateRuntimeContext, Float) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _resume: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _reset: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    fileprivate let _shutdown: @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    internal init(
        internalContext: WatchAudioStateRuntimeContext,
        _initialize: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _audioReady: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _audioFailed: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _playString: @escaping @Sendable (WatchAudioStateRuntimeContext, String) async throws -> WatchAudioStateRuntimeContext,
        _pause: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _stop: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _trackEnded: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _adjustVolumeFloat: @escaping @Sendable (WatchAudioStateRuntimeContext, Float) async throws -> WatchAudioStateRuntimeContext,
        _resume: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _reset: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext,
        _shutdown: @escaping @Sendable (WatchAudioStateRuntimeContext) async throws -> WatchAudioStateRuntimeContext
    ) {
        self.internalContext = internalContext

        self._initialize = _initialize
        self._audioReady = _audioReady
        self._audioFailed = _audioFailed
        self._playString = _playString
        self._pause = _pause
        self._stop = _stop
        self._trackEnded = _trackEnded
        self._adjustVolumeFloat = _adjustVolumeFloat
        self._resume = _resume
        self._reset = _reset
        self._shutdown = _shutdown
    }

    /// Access the internal context while preserving borrowing semantics.
    internal borrowing func withInternalContext<R>(_ body: (borrowing WatchAudioStateRuntimeContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - WatchAudio.Off Transitions

extension WatchAudioMachine where State == WatchAudioStateOff {
    /// Initialise AVAudioSession and claim the audio route
    public consuming func initialize() async throws -> WatchAudioMachine<WatchAudioStateInitializing> {
        let nextContext = try await self._initialize(self.internalContext)
        return WatchAudioMachine<WatchAudioStateInitializing>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }
}

// MARK: - WatchAudio.Initializing Transitions

extension WatchAudioMachine where State == WatchAudioStateInitializing {
    /// Audio session is active and the output route is confirmed
    public consuming func audioReady() async throws -> WatchAudioMachine<WatchAudioStateIdle> {
        let nextContext = try await self._audioReady(self.internalContext)
        return WatchAudioMachine<WatchAudioStateIdle>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// AVAudioSession activation failed (e.g. interrupted by a phone call)
    public consuming func audioFailed() async throws -> WatchAudioMachine<WatchAudioStateError> {
        let nextContext = try await self._audioFailed(self.internalContext)
        return WatchAudioMachine<WatchAudioStateError>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }
}

// MARK: - WatchAudio.Idle Transitions

extension WatchAudioMachine where State == WatchAudioStateIdle {
    /// Begin playback of a track identified by its resource path or URL string
    public consuming func play(trackId: String) async throws -> WatchAudioMachine<WatchAudioStatePlaying> {
        let nextContext = try await self._playString(self.internalContext, trackId)
        return WatchAudioMachine<WatchAudioStatePlaying>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Deactivate AVAudioSession and release all resources
    public consuming func shutdown() async throws -> WatchAudioMachine<WatchAudioStateTerminated> {
        let nextContext = try await self._shutdown(self.internalContext)
        return WatchAudioMachine<WatchAudioStateTerminated>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }
}

// MARK: - WatchAudio.Playing Transitions

extension WatchAudioMachine where State == WatchAudioStatePlaying {
    /// Pause without releasing the audio session
    public consuming func pause() async throws -> WatchAudioMachine<WatchAudioStatePaused> {
        let nextContext = try await self._pause(self.internalContext)
        return WatchAudioMachine<WatchAudioStatePaused>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Stop playback and release the current track; keep the session open
    public consuming func stop() async throws -> WatchAudioMachine<WatchAudioStateIdle> {
        let nextContext = try await self._stop(self.internalContext)
        return WatchAudioMachine<WatchAudioStateIdle>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Playback reached the natural end of the track
    public consuming func trackEnded() async throws -> WatchAudioMachine<WatchAudioStateIdle> {
        let nextContext = try await self._trackEnded(self.internalContext)
        return WatchAudioMachine<WatchAudioStateIdle>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Adjust output volume without interrupting playback (self-loop)
    public consuming func adjustVolume(level: Float) async throws -> WatchAudioMachine<WatchAudioStatePlaying> {
        let nextContext = try await self._adjustVolumeFloat(self.internalContext, level)
        return WatchAudioMachine<WatchAudioStatePlaying>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Handles the `shutdown` transition from Playing to Terminated.
    public consuming func shutdown() async throws -> WatchAudioMachine<WatchAudioStateTerminated> {
        let nextContext = try await self._shutdown(self.internalContext)
        return WatchAudioMachine<WatchAudioStateTerminated>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }
}

// MARK: - WatchAudio.Paused Transitions

extension WatchAudioMachine where State == WatchAudioStatePaused {
    /// Resume from the paused position
    public consuming func resume() async throws -> WatchAudioMachine<WatchAudioStatePlaying> {
        let nextContext = try await self._resume(self.internalContext)
        return WatchAudioMachine<WatchAudioStatePlaying>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Discard the paused track; keep the session open
    public consuming func stop() async throws -> WatchAudioMachine<WatchAudioStateIdle> {
        let nextContext = try await self._stop(self.internalContext)
        return WatchAudioMachine<WatchAudioStateIdle>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Handles the `shutdown` transition from Paused to Terminated.
    public consuming func shutdown() async throws -> WatchAudioMachine<WatchAudioStateTerminated> {
        let nextContext = try await self._shutdown(self.internalContext)
        return WatchAudioMachine<WatchAudioStateTerminated>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }
}

// MARK: - WatchAudio.Error Transitions

extension WatchAudioMachine where State == WatchAudioStateError {
    /// Attempt to recover from the failed state (e.g. after an interruption ends)
    public consuming func reset() async throws -> WatchAudioMachine<WatchAudioStateOff> {
        let nextContext = try await self._reset(self.internalContext)
        return WatchAudioMachine<WatchAudioStateOff>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }

    /// Handles the `shutdown` transition from Error to Terminated.
    public consuming func shutdown() async throws -> WatchAudioMachine<WatchAudioStateTerminated> {
        let nextContext = try await self._shutdown(self.internalContext)
        return WatchAudioMachine<WatchAudioStateTerminated>(
            internalContext: nextContext,
                _initialize: self._initialize,
                _audioReady: self._audioReady,
                _audioFailed: self._audioFailed,
                _playString: self._playString,
                _pause: self._pause,
                _stop: self._stop,
                _trackEnded: self._trackEnded,
                _adjustVolumeFloat: self._adjustVolumeFloat,
                _resume: self._resume,
                _reset: self._reset,
                _shutdown: self._shutdown
        )
    }
}

// MARK: - WatchAudio Combined State

/// A runtime-friendly wrapper over all observer states.
public enum WatchAudioState: ~Copyable {
    case off(WatchAudioMachine<WatchAudioStateOff>)
    case initializing(WatchAudioMachine<WatchAudioStateInitializing>)
    case idle(WatchAudioMachine<WatchAudioStateIdle>)
    case playing(WatchAudioMachine<WatchAudioStatePlaying>)
    case paused(WatchAudioMachine<WatchAudioStatePaused>)
    case error(WatchAudioMachine<WatchAudioStateError>)
    case terminated(WatchAudioMachine<WatchAudioStateTerminated>)

    public init(_ machine: consuming WatchAudioMachine<WatchAudioStateOff>) {
        self = .off(machine)
    }
}

extension WatchAudioState {
    public borrowing func withOff<R>(_ body: (borrowing WatchAudioMachine<WatchAudioStateOff>) throws -> R) rethrows -> R? {
        switch self {
        case let .off(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withInitializing<R>(_ body: (borrowing WatchAudioMachine<WatchAudioStateInitializing>) throws -> R) rethrows -> R? {
        switch self {
        case let .initializing(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withIdle<R>(_ body: (borrowing WatchAudioMachine<WatchAudioStateIdle>) throws -> R) rethrows -> R? {
        switch self {
        case let .idle(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withPlaying<R>(_ body: (borrowing WatchAudioMachine<WatchAudioStatePlaying>) throws -> R) rethrows -> R? {
        switch self {
        case let .playing(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withPaused<R>(_ body: (borrowing WatchAudioMachine<WatchAudioStatePaused>) throws -> R) rethrows -> R? {
        switch self {
        case let .paused(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withError<R>(_ body: (borrowing WatchAudioMachine<WatchAudioStateError>) throws -> R) rethrows -> R? {
        switch self {
        case let .error(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withTerminated<R>(_ body: (borrowing WatchAudioMachine<WatchAudioStateTerminated>) throws -> R) rethrows -> R? {
        switch self {
        case let .terminated(observer):
            return try body(observer)
        default:
            return nil
        }
    }


    /// Attempts the `initialize` transition from the current wrapper state.
    public consuming func initialize() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .initializing(try await observer.initialize())
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .playing(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `audioReady` transition from the current wrapper state.
    public consuming func audioReady() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .idle(try await observer.audioReady())
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .playing(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `audioFailed` transition from the current wrapper state.
    public consuming func audioFailed() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .error(try await observer.audioFailed())
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .playing(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `play` transition from the current wrapper state.
    public consuming func play(trackId: String) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .playing(try await observer.play(trackId: trackId))
    case let .playing(observer):
        return .playing(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `pause` transition from the current wrapper state.
    public consuming func pause() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .paused(try await observer.pause())
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `stop` transition from the current wrapper state.
    public consuming func stop() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .idle(try await observer.stop())
    case let .paused(observer):
        return .idle(try await observer.stop())
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `trackEnded` transition from the current wrapper state.
    public consuming func trackEnded() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .idle(try await observer.trackEnded())
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `adjustVolume` transition from the current wrapper state.
    public consuming func adjustVolume(level: Float) async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .playing(try await observer.adjustVolume(level: level))
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `resume` transition from the current wrapper state.
    public consuming func resume() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .playing(observer)
    case let .paused(observer):
        return .playing(try await observer.resume())
    case let .error(observer):
        return .error(observer)
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `reset` transition from the current wrapper state.
    public consuming func reset() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .idle(observer)
    case let .playing(observer):
        return .playing(observer)
    case let .paused(observer):
        return .paused(observer)
    case let .error(observer):
        return .off(try await observer.reset())
    case let .terminated(observer):
        return .terminated(observer)
        }
    }

    /// Attempts the `shutdown` transition from the current wrapper state.
    public consuming func shutdown() async throws -> Self {
        switch consume self {
    case let .off(observer):
        return .off(observer)
    case let .initializing(observer):
        return .initializing(observer)
    case let .idle(observer):
        return .terminated(try await observer.shutdown())
    case let .playing(observer):
        return .terminated(try await observer.shutdown())
    case let .paused(observer):
        return .terminated(try await observer.shutdown())
    case let .error(observer):
        return .terminated(try await observer.shutdown())
    case let .terminated(observer):
        return .terminated(observer)
        }
    }
}
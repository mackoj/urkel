import Foundation
import Dependencies

// MARK: - UrkelBird State Machine

/// Typestate markers for the `UrkelBird` machine.
public enum UrkelBirdMachine {
    public enum Ready {}
    public enum Playing {}
    public enum Crashed {}
}

// MARK: - UrkelBird Runtime Context Bridge

/// Internal state-aware context wrapper used by generated runtime helpers.
struct UrkelBirdRuntimeContext: Sendable {
    enum Storage: Sendable {
        case ready(UrkelBirdContext)
        case playing(UrkelBirdContext)
        case crashed(UrkelBirdContext)
    }

    let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

static func ready(_ value: UrkelBirdContext) -> Self {
    .init(storage: .ready(value))
}

static func playing(_ value: UrkelBirdContext) -> Self {
    .init(storage: .playing(value))
}

static func crashed(_ value: UrkelBirdContext) -> Self {
    .init(storage: .crashed(value))
}
}

// MARK: - UrkelBird Observer

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct UrkelBirdObserver<State>: ~Copyable {
    private var internalContext: UrkelBirdContext

    private let _flap: @Sendable (UrkelBirdContext) async throws -> UrkelBirdContext
    private let _tickDeltaYInt: @Sendable (UrkelBirdContext, Int) async throws -> UrkelBirdContext
    private let _scorePipe: @Sendable (UrkelBirdContext) async throws -> UrkelBirdContext
    private let _collideReasonString: @Sendable (UrkelBirdContext, String) async throws -> UrkelBirdContext

    public init(
        internalContext: UrkelBirdContext,
        _flap: @escaping @Sendable (UrkelBirdContext) async throws -> UrkelBirdContext,
        _tickDeltaYInt: @escaping @Sendable (UrkelBirdContext, Int) async throws -> UrkelBirdContext,
        _scorePipe: @escaping @Sendable (UrkelBirdContext) async throws -> UrkelBirdContext,
        _collideReasonString: @escaping @Sendable (UrkelBirdContext, String) async throws -> UrkelBirdContext
    ) {
        self.internalContext = internalContext

        self._flap = _flap
        self._tickDeltaYInt = _tickDeltaYInt
        self._scorePipe = _scorePipe
        self._collideReasonString = _collideReasonString
    }

    /// Access the internal context while preserving borrowing semantics.
    public borrowing func withInternalContext<R>(_ body: (borrowing UrkelBirdContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - UrkelBird Runtime Stream

/// Generic stream lifecycle helper for event-driven runtimes generated from this machine.
actor UrkelBirdRuntimeStream<Element: Sendable> {
    nonisolated let events: AsyncThrowingStream<Element, Error>

    private var continuation: AsyncThrowingStream<Element, Error>.Continuation?
    private var pendingEvent: Element?
    private var debounceTask: Task<Void, Never>?
    private let debounceMs: Int

    init(debounceMs: Int = 0) {
        self.debounceMs = max(0, debounceMs)

        var capturedContinuation: AsyncThrowingStream<Element, Error>.Continuation?
        self.events = AsyncThrowingStream<Element, Error> { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    func emit(_ event: Element) {
        guard let continuation else { return }

        if debounceMs == 0 {
            continuation.yield(event)
            return
        }

        pendingEvent = event
        debounceTask?.cancel()
        debounceTask = Task { [debounceMs] in
            try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
            self.flushPendingEvent()
        }
    }

    func finish(throwing error: Error? = nil) {
        debounceTask?.cancel()
        debounceTask = nil
        pendingEvent = nil
        continuation?.finish(throwing: error)
        continuation = nil
    }

    private func flushPendingEvent() {
        guard let event = pendingEvent else { return }
        pendingEvent = nil
        continuation?.yield(event)
    }
}

// MARK: - UrkelBird Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct UrkelBirdClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> UrkelBirdContext
    typealias FlapTransition = @Sendable (UrkelBirdContext) async throws -> UrkelBirdContext
    typealias TickDeltaYIntTransition = @Sendable (UrkelBirdContext, Int) async throws -> UrkelBirdContext
    typealias ScorePipeTransition = @Sendable (UrkelBirdContext) async throws -> UrkelBirdContext
    typealias CollideReasonStringTransition = @Sendable (UrkelBirdContext, String) async throws -> UrkelBirdContext
    let initialContext: InitialContextBuilder
    let flapTransition: FlapTransition
    let tickDeltaYIntTransition: TickDeltaYIntTransition
    let scorePipeTransition: ScorePipeTransition
    let collideReasonStringTransition: CollideReasonStringTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        flapTransition: @escaping FlapTransition,
        tickDeltaYIntTransition: @escaping TickDeltaYIntTransition,
        scorePipeTransition: @escaping ScorePipeTransition,
        collideReasonStringTransition: @escaping CollideReasonStringTransition
    ) {
        self.initialContext = initialContext
        self.flapTransition = flapTransition
        self.tickDeltaYIntTransition = tickDeltaYIntTransition
        self.scorePipeTransition = scorePipeTransition
        self.collideReasonStringTransition = collideReasonStringTransition
    }
}

extension UrkelBirdClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: UrkelBirdClientRuntime) -> Self {
        Self(
            makeGame: {
                let context = runtime.initialContext()
                return UrkelBirdObserver<UrkelBirdMachine.Ready>(
                    internalContext: context,
                _flap: runtime.flapTransition,
                _tickDeltaYInt: runtime.tickDeltaYIntTransition,
                _scorePipe: runtime.scorePipeTransition,
                _collideReasonString: runtime.collideReasonStringTransition
                )
            }
        )
    }
}

// MARK: - UrkelBird.Ready Transitions

extension UrkelBirdObserver where State == UrkelBirdMachine.Ready {
    /// Handles the `flap` transition from Ready to Playing.
    public consuming func flap() async throws -> UrkelBirdObserver<UrkelBirdMachine.Playing> {
        let nextContext = try await self._flap(self.internalContext)
        return UrkelBirdObserver<UrkelBirdMachine.Playing>(
            internalContext: nextContext,
                _flap: self._flap,
                _tickDeltaYInt: self._tickDeltaYInt,
                _scorePipe: self._scorePipe,
                _collideReasonString: self._collideReasonString
        )
    }
}

// MARK: - UrkelBird.Playing Transitions

extension UrkelBirdObserver where State == UrkelBirdMachine.Playing {
    /// Handles the `flap` transition from Playing to Playing.
    public consuming func flap() async throws -> UrkelBirdObserver<UrkelBirdMachine.Playing> {
        let nextContext = try await self._flap(self.internalContext)
        return UrkelBirdObserver<UrkelBirdMachine.Playing>(
            internalContext: nextContext,
                _flap: self._flap,
                _tickDeltaYInt: self._tickDeltaYInt,
                _scorePipe: self._scorePipe,
                _collideReasonString: self._collideReasonString
        )
    }

    /// Handles the `tick` transition from Playing to Playing.
    public consuming func tick(deltaY: Int) async throws -> UrkelBirdObserver<UrkelBirdMachine.Playing> {
        let nextContext = try await self._tickDeltaYInt(self.internalContext, deltaY)
        return UrkelBirdObserver<UrkelBirdMachine.Playing>(
            internalContext: nextContext,
                _flap: self._flap,
                _tickDeltaYInt: self._tickDeltaYInt,
                _scorePipe: self._scorePipe,
                _collideReasonString: self._collideReasonString
        )
    }

    /// Handles the `scorePipe` transition from Playing to Playing.
    public consuming func scorePipe() async throws -> UrkelBirdObserver<UrkelBirdMachine.Playing> {
        let nextContext = try await self._scorePipe(self.internalContext)
        return UrkelBirdObserver<UrkelBirdMachine.Playing>(
            internalContext: nextContext,
                _flap: self._flap,
                _tickDeltaYInt: self._tickDeltaYInt,
                _scorePipe: self._scorePipe,
                _collideReasonString: self._collideReasonString
        )
    }

    /// Handles the `collide` transition from Playing to Crashed.
    public consuming func collide(reason: String) async throws -> UrkelBirdObserver<UrkelBirdMachine.Crashed> {
        let nextContext = try await self._collideReasonString(self.internalContext, reason)
        return UrkelBirdObserver<UrkelBirdMachine.Crashed>(
            internalContext: nextContext,
                _flap: self._flap,
                _tickDeltaYInt: self._tickDeltaYInt,
                _scorePipe: self._scorePipe,
                _collideReasonString: self._collideReasonString
        )
    }
}

// MARK: - UrkelBird Combined State

/// A runtime-friendly wrapper over all observer states.
public enum UrkelBirdState: ~Copyable {
    case ready(UrkelBirdObserver<UrkelBirdMachine.Ready>)
    case playing(UrkelBirdObserver<UrkelBirdMachine.Playing>)
    case crashed(UrkelBirdObserver<UrkelBirdMachine.Crashed>)

    public init(_ observer: consuming UrkelBirdObserver<UrkelBirdMachine.Ready>) {
        self = .ready(observer)
    }
}

extension UrkelBirdState {
    public borrowing func withReady<R>(_ body: (borrowing UrkelBirdObserver<UrkelBirdMachine.Ready>) throws -> R) rethrows -> R? {
        switch self {
        case let .ready(observer):
            return try body(observer)

        case .playing:
            return nil
        case .crashed:
            return nil
        }
    }

    public borrowing func withPlaying<R>(_ body: (borrowing UrkelBirdObserver<UrkelBirdMachine.Playing>) throws -> R) rethrows -> R? {
        switch self {
        case let .playing(observer):
            return try body(observer)

        case .ready:
            return nil
        case .crashed:
            return nil
        }
    }

    public borrowing func withCrashed<R>(_ body: (borrowing UrkelBirdObserver<UrkelBirdMachine.Crashed>) throws -> R) rethrows -> R? {
        switch self {
        case let .crashed(observer):
            return try body(observer)

        case .ready:
            return nil
        case .playing:
            return nil
        }
    }


    /// Attempts the `flap` transition from the current wrapper state.
    public consuming func flap() async throws -> Self {
        switch consume self {
    case let .ready(observer):
        let next = try await observer.flap()
        return .playing(next)
    case let .playing(observer):
        let next = try await observer.flap()
        return .playing(next)
    case let .crashed(observer):
        return .crashed(observer)
        }
    }

    /// Attempts the `tick` transition from the current wrapper state.
    public consuming func tick(deltaY: Int) async throws -> Self {
        switch consume self {
    case let .ready(observer):
        return .ready(observer)
    case let .playing(observer):
        let next = try await observer.tick(deltaY: deltaY)
        return .playing(next)
    case let .crashed(observer):
        return .crashed(observer)
        }
    }

    /// Attempts the `scorePipe` transition from the current wrapper state.
    public consuming func scorePipe() async throws -> Self {
        switch consume self {
    case let .ready(observer):
        return .ready(observer)
    case let .playing(observer):
        let next = try await observer.scorePipe()
        return .playing(next)
    case let .crashed(observer):
        return .crashed(observer)
        }
    }

    /// Attempts the `collide` transition from the current wrapper state.
    public consuming func collide(reason: String) async throws -> Self {
        switch consume self {
    case let .ready(observer):
        return .ready(observer)
    case let .playing(observer):
        let next = try await observer.collide(reason: reason)
        return .crashed(next)
    case let .crashed(observer):
        return .crashed(observer)
        }
    }
}

// MARK: - UrkelBird Client

/// Dependency client entry point for constructing UrkelBird observers.
public struct UrkelBirdClient: Sendable {
    public var makeGame: @Sendable () -> UrkelBirdObserver<UrkelBirdMachine.Ready>

    public init(makeGame: @escaping @Sendable () -> UrkelBirdObserver<UrkelBirdMachine.Ready>) {
        self.makeGame = makeGame
    }
}

extension UrkelBirdClient: DependencyKey {
    public static let testValue = Self(
        makeGame: {
                    fatalError("Configure UrkelBirdClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeGame: {
                    fatalError("Configure UrkelBirdClient.previewValue in previews.")
                }
    )

    public static let liveValue = Self(
        makeGame: {
                    fatalError("Configure UrkelBirdClient.liveValue in your app target.")
                }
    )
}

extension DependencyValues {
    /// Accessor for the generated UrkelBirdClient dependency.
    public var urkelBird: UrkelBirdClient {
        get { self[UrkelBirdClient.self] }
        set { self[UrkelBirdClient.self] = newValue }
    }
}
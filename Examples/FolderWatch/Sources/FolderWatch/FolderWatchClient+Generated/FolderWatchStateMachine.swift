import Foundation
import Dependencies

// MARK: - FolderWatch State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct FolderWatchStateMachine<Phase>: ~Copyable {
    public enum State {
        public enum Idle {}
        public enum Running {}
        public enum Stopped {}
    }
    private var internalContext: FolderWatchContext

    private let _start: @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    private let _stop: @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    public init(
        internalContext: FolderWatchContext,
        _start: @escaping @Sendable (FolderWatchContext) async throws -> FolderWatchContext,
        _stop: @escaping @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    ) {
        self.internalContext = internalContext

        self._start = _start
        self._stop = _stop
    }

    /// Access the internal context while preserving borrowing semantics.
    public borrowing func withInternalContext<R>(_ body: (borrowing FolderWatchContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - FolderWatch.Idle Transitions

extension FolderWatchStateMachine where Phase == FolderWatchStateMachine.State.Idle {
    /// Handles the `start` transition from Idle to Running.
    public consuming func start() async throws -> FolderWatchStateMachine<FolderWatchStateMachine.State.Running> {
        let nextContext = try await self._start(self.internalContext)
        return FolderWatchStateMachine<FolderWatchStateMachine.State.Running>(
            internalContext: nextContext,
                _start: self._start,
                _stop: self._stop
        )
    }
}

// MARK: - FolderWatch.Running Transitions

extension FolderWatchStateMachine where Phase == FolderWatchStateMachine.State.Running {
    /// Handles the `stop` transition from Running to Stopped.
    public consuming func stop() async throws -> FolderWatchStateMachine<FolderWatchStateMachine.State.Stopped> {
        let nextContext = try await self._stop(self.internalContext)
        return FolderWatchStateMachine<FolderWatchStateMachine.State.Stopped>(
            internalContext: nextContext,
                _start: self._start,
                _stop: self._stop
        )
    }
}

// MARK: - FolderWatch Combined State

/// A runtime-friendly wrapper over all observer states.
public enum FolderWatchState: ~Copyable {
    case idle(FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>)
    case running(FolderWatchStateMachine<FolderWatchStateMachine.State.Running>)
    case stopped(FolderWatchStateMachine<FolderWatchStateMachine.State.Stopped>)

    public init(_ observer: consuming FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>) {
        self = .idle(observer)
    }
}

extension FolderWatchState {
    public borrowing func withIdle<R>(_ body: (borrowing FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>) throws -> R) rethrows -> R? {
        switch self {
        case let .idle(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withRunning<R>(_ body: (borrowing FolderWatchStateMachine<FolderWatchStateMachine.State.Running>) throws -> R) rethrows -> R? {
        switch self {
        case let .running(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withStopped<R>(_ body: (borrowing FolderWatchStateMachine<FolderWatchStateMachine.State.Stopped>) throws -> R) rethrows -> R? {
        switch self {
        case let .stopped(observer):
            return try body(observer)
        default:
            return nil
        }
    }


    /// Attempts the `start` transition from the current wrapper state.
    public consuming func start() async throws -> Self {
        switch consume self {
    case let .idle(observer):
        let next = try await observer.start()
        return .running(next)
    case let .running(observer):
        return .running(observer)
    case let .stopped(observer):
        return .stopped(observer)
        }
    }

    /// Attempts the `stop` transition from the current wrapper state.
    public consuming func stop() async throws -> Self {
        switch consume self {
    case let .idle(observer):
        return .idle(observer)
    case let .running(observer):
        let next = try await observer.stop()
        return .stopped(next)
    case let .stopped(observer):
        return .stopped(observer)
        }
    }
}
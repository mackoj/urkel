import Foundation
import Dependencies

// MARK: - FolderWatch Typestate Markers

public enum FolderWatchStateIdle {}
public enum FolderWatchStateRunning {}
public enum FolderWatchStateStopped {}

// MARK: - FolderWatch State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct FolderWatchMachine<State>: ~Copyable {
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

extension FolderWatchMachine where State == FolderWatchStateIdle {
    /// Handles the `start` transition from Idle to Running.
    public consuming func start() async throws -> FolderWatchMachine<FolderWatchStateRunning> {
        let nextContext = try await self._start(self.internalContext)
        return FolderWatchMachine<FolderWatchStateRunning>(
            internalContext: nextContext,
                _start: self._start,
                _stop: self._stop
        )
    }
}

// MARK: - FolderWatch.Running Transitions

extension FolderWatchMachine where State == FolderWatchStateRunning {
    /// Handles the `stop` transition from Running to Stopped.
    public consuming func stop() async throws -> FolderWatchMachine<FolderWatchStateStopped> {
        let nextContext = try await self._stop(self.internalContext)
        return FolderWatchMachine<FolderWatchStateStopped>(
            internalContext: nextContext,
                _start: self._start,
                _stop: self._stop
        )
    }
}

// MARK: - FolderWatch Combined State

/// A runtime-friendly wrapper over all observer states.
public enum FolderWatchState: ~Copyable {
    case idle(FolderWatchMachine<FolderWatchStateIdle>)
    case running(FolderWatchMachine<FolderWatchStateRunning>)
    case stopped(FolderWatchMachine<FolderWatchStateStopped>)

    public init(_ machine: consuming FolderWatchMachine<FolderWatchStateIdle>) {
        self = .idle(machine)
    }
}

extension FolderWatchState {
    public borrowing func withIdle<R>(_ body: (borrowing FolderWatchMachine<FolderWatchStateIdle>) throws -> R) rethrows -> R? {
        switch self {
        case let .idle(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withRunning<R>(_ body: (borrowing FolderWatchMachine<FolderWatchStateRunning>) throws -> R) rethrows -> R? {
        switch self {
        case let .running(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withStopped<R>(_ body: (borrowing FolderWatchMachine<FolderWatchStateStopped>) throws -> R) rethrows -> R? {
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
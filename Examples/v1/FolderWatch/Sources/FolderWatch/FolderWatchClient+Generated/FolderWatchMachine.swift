import Foundation
import Dependencies

// MARK: - FolderWatch Typestate Markers

public enum FolderWatchStateIdle {}
public enum FolderWatchStateRunning {}
public enum FolderWatchStateStopped {}

// MARK: - FolderWatch State Machine

/// A type-safe state machine encoding the current state in its generic parameter.
public struct FolderWatchMachine<State>: ~Copyable {
    public let directory: URL
    public let debounceMs: Int

    fileprivate let _startTransition: (@Sendable () async -> FolderWatchMachine<FolderWatchStateRunning>)?
    fileprivate let _errorErrorTransition: (@Sendable (Error) async -> FolderWatchMachine<FolderWatchStateRunning>)?
    fileprivate let _stopTransition: (@Sendable () async -> FolderWatchMachine<FolderWatchStateStopped>)?
    fileprivate let _eventsAccessor: (@Sendable () -> AsyncThrowingStream<DirectoryEvent, Error>)?

    // MARK: Idle State Init
    internal init(
        directory: URL,
        debounceMs: Int,
        startTransition: @escaping @Sendable () async -> FolderWatchMachine<FolderWatchStateRunning>
    ) where State == FolderWatchStateIdle {
        self.directory = directory
        self.debounceMs = debounceMs
        _startTransition = startTransition
        _errorErrorTransition = nil
        _stopTransition = nil
        _eventsAccessor = nil
    }

    // MARK: Running State Init
    internal init(
        directory: URL,
        debounceMs: Int,
        errorErrorTransition: @escaping @Sendable (Error) async -> FolderWatchMachine<FolderWatchStateRunning>,
        stopTransition: @escaping @Sendable () async -> FolderWatchMachine<FolderWatchStateStopped>,
        eventsAccessor: @escaping @Sendable () -> AsyncThrowingStream<DirectoryEvent, Error>
    ) where State == FolderWatchStateRunning {
        self.directory = directory
        self.debounceMs = debounceMs
        _errorErrorTransition = errorErrorTransition
        _stopTransition = stopTransition
        _startTransition = nil
        _eventsAccessor = eventsAccessor
    }

    // MARK: Stopped State Init
    internal init(
        directory: URL,
        debounceMs: Int
    ) where State == FolderWatchStateStopped {
        self.directory = directory
        self.debounceMs = debounceMs
        _startTransition = nil
        _errorErrorTransition = nil
        _stopTransition = nil
        _eventsAccessor = nil
    }
}

// MARK: - FolderWatch.Idle Transitions

extension FolderWatchMachine where State == FolderWatchStateIdle {
    /// Handles the `start` transition from Idle to Running.
    public consuming func start() async -> FolderWatchMachine<FolderWatchStateRunning> {
        await _startTransition!()
    }
}

// MARK: - FolderWatch.Running Transitions

extension FolderWatchMachine where State == FolderWatchStateRunning {
    /// Handles the `error` transition from Running to Running.
    public consuming func error(error: Error) async -> FolderWatchMachine<FolderWatchStateRunning> {
        await _errorErrorTransition!(error)
    }

    /// Handles the `stop` transition from Running to Stopped.
    public consuming func stop() async -> FolderWatchMachine<FolderWatchStateStopped> {
        await _stopTransition!()
    }

    /// Returns the events accessor while in the Running state.
    public var events: AsyncThrowingStream<DirectoryEvent, Error> {
        _eventsAccessor!()
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
    public mutating func start() async {
        switch consume self {
    case let .idle(observer):
        self = .running(await observer.start())
    case let .running(observer):
        self = .running(observer)
    case let .stopped(observer):
        self = .stopped(observer)
        }
    }

    /// Attempts the `error` transition from the current wrapper state.
    public mutating func error(error: Error) async {
        switch consume self {
    case let .idle(observer):
        self = .idle(observer)
    case let .running(observer):
        self = .running(await observer.error(error: error))
    case let .stopped(observer):
        self = .stopped(observer)
        }
    }

    /// Attempts the `stop` transition from the current wrapper state.
    public mutating func stop() async {
        switch consume self {
    case let .idle(observer):
        self = .idle(observer)
    case let .running(observer):
        self = .stopped(await observer.stop())
    case let .stopped(observer):
        self = .stopped(observer)
        }
    }
}
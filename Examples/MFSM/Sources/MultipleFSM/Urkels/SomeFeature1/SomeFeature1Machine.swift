import Foundation
import Dependencies

// MARK: - SomeFeature1 Typestate Markers

public enum SomeFeature1StateIdle {}
public enum SomeFeature1StateRunning {}
public enum SomeFeature1StateStopped {}
internal struct SomeFeature1StateRuntimeContext: Sendable {
    init() {}
}

// MARK: - SomeFeature1 State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct SomeFeature1Machine<State>: ~Copyable, Sendable {
    private var internalContext: SomeFeature1StateRuntimeContext

    fileprivate let _start: @Sendable (SomeFeature1StateRuntimeContext) async throws -> SomeFeature1StateRuntimeContext
    fileprivate let _errorError: @Sendable (SomeFeature1StateRuntimeContext, Error) async throws -> SomeFeature1StateRuntimeContext
    fileprivate let _stop: @Sendable (SomeFeature1StateRuntimeContext) async throws -> SomeFeature1StateRuntimeContext
    internal init(
        internalContext: SomeFeature1StateRuntimeContext,
        _start: @escaping @Sendable (SomeFeature1StateRuntimeContext) async throws -> SomeFeature1StateRuntimeContext,
        _errorError: @escaping @Sendable (SomeFeature1StateRuntimeContext, Error) async throws -> SomeFeature1StateRuntimeContext,
        _stop: @escaping @Sendable (SomeFeature1StateRuntimeContext) async throws -> SomeFeature1StateRuntimeContext
    ) {
        self.internalContext = internalContext

        self._start = _start
        self._errorError = _errorError
        self._stop = _stop
    }

    /// Access the internal context while preserving borrowing semantics.
    internal borrowing func withInternalContext<R>(_ body: (borrowing SomeFeature1StateRuntimeContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - SomeFeature1.Idle Transitions

extension SomeFeature1Machine where State == SomeFeature1StateIdle {
    /// Handles the `start` transition from Idle to Running.
    public consuming func start() async throws -> SomeFeature1Machine<SomeFeature1StateRunning> {
        let nextContext = try await self._start(self.internalContext)
        return SomeFeature1Machine<SomeFeature1StateRunning>(
            internalContext: nextContext,
                _start: self._start,
                _errorError: self._errorError,
                _stop: self._stop
        )
    }
}

// MARK: - SomeFeature1.Running Transitions

extension SomeFeature1Machine where State == SomeFeature1StateRunning {
    /// Handles the `error` transition from Running to Stopped.
    public consuming func error(error: Error) async throws -> SomeFeature1Machine<SomeFeature1StateStopped> {
        let nextContext = try await self._errorError(self.internalContext, error)
        return SomeFeature1Machine<SomeFeature1StateStopped>(
            internalContext: nextContext,
                _start: self._start,
                _errorError: self._errorError,
                _stop: self._stop
        )
    }

    /// Handles the `stop` transition from Running to Stopped.
    public consuming func stop() async throws -> SomeFeature1Machine<SomeFeature1StateStopped> {
        let nextContext = try await self._stop(self.internalContext)
        return SomeFeature1Machine<SomeFeature1StateStopped>(
            internalContext: nextContext,
                _start: self._start,
                _errorError: self._errorError,
                _stop: self._stop
        )
    }
}

// MARK: - SomeFeature1 Combined State

/// A runtime-friendly wrapper over all observer states.
public enum SomeFeature1State: ~Copyable, Sendable {
    case idle(SomeFeature1Machine<SomeFeature1StateIdle>)
    case running(SomeFeature1Machine<SomeFeature1StateRunning>)
    case stopped(SomeFeature1Machine<SomeFeature1StateStopped>)

    public init(_ machine: consuming SomeFeature1Machine<SomeFeature1StateIdle>) {
        self = .idle(machine)
    }
}

extension SomeFeature1State {
    public borrowing func withIdle<R>(_ body: (borrowing SomeFeature1Machine<SomeFeature1StateIdle>) throws -> R) rethrows -> R? {
        switch self {
        case let .idle(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withRunning<R>(_ body: (borrowing SomeFeature1Machine<SomeFeature1StateRunning>) throws -> R) rethrows -> R? {
        switch self {
        case let .running(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withStopped<R>(_ body: (borrowing SomeFeature1Machine<SomeFeature1StateStopped>) throws -> R) rethrows -> R? {
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
        return .running(try await observer.start())
    case let .running(observer):
        return .running(observer)
    case let .stopped(observer):
        return .stopped(observer)
        }
    }

    /// Attempts the `error` transition from the current wrapper state.
    public consuming func error(error: Error) async throws -> Self {
        switch consume self {
    case let .idle(observer):
        return .idle(observer)
    case let .running(observer):
        return .stopped(try await observer.error(error: error))
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
        return .stopped(try await observer.stop())
    case let .stopped(observer):
        return .stopped(observer)
        }
    }
}
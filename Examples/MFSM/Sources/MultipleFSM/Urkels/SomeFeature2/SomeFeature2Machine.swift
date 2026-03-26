import Foundation
import Dependencies

// MARK: - SomeFeature2 Typestate Markers

public enum SomeFeature2StateIdle {}
public enum SomeFeature2StateRunning {}
public enum SomeFeature2StateStopped {}
internal struct SomeFeature2StateRuntimeContext: Sendable {
    init() {}
}

// MARK: - SomeFeature2 State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct SomeFeature2Machine<State>: ~Copyable, Sendable {
    private var internalContext: SomeFeature2StateRuntimeContext

    fileprivate let _start: @Sendable (SomeFeature2StateRuntimeContext) async throws -> SomeFeature2StateRuntimeContext
    fileprivate let _errorError: @Sendable (SomeFeature2StateRuntimeContext, Error) async throws -> SomeFeature2StateRuntimeContext
    fileprivate let _stop: @Sendable (SomeFeature2StateRuntimeContext) async throws -> SomeFeature2StateRuntimeContext
    internal init(
        internalContext: SomeFeature2StateRuntimeContext,
        _start: @escaping @Sendable (SomeFeature2StateRuntimeContext) async throws -> SomeFeature2StateRuntimeContext,
        _errorError: @escaping @Sendable (SomeFeature2StateRuntimeContext, Error) async throws -> SomeFeature2StateRuntimeContext,
        _stop: @escaping @Sendable (SomeFeature2StateRuntimeContext) async throws -> SomeFeature2StateRuntimeContext
    ) {
        self.internalContext = internalContext

        self._start = _start
        self._errorError = _errorError
        self._stop = _stop
    }

    /// Access the internal context while preserving borrowing semantics.
    internal borrowing func withInternalContext<R>(_ body: (borrowing SomeFeature2StateRuntimeContext) throws -> R) rethrows -> R {
        try body(self.internalContext)
    }
}

// MARK: - SomeFeature2.Idle Transitions

extension SomeFeature2Machine where State == SomeFeature2StateIdle {
    /// Handles the `start` transition from Idle to Running.
    public consuming func start() async throws -> SomeFeature2Machine<SomeFeature2StateRunning> {
        let nextContext = try await self._start(self.internalContext)
        return SomeFeature2Machine<SomeFeature2StateRunning>(
            internalContext: nextContext,
                _start: self._start,
                _errorError: self._errorError,
                _stop: self._stop
        )
    }
}

// MARK: - SomeFeature2.Running Transitions

extension SomeFeature2Machine where State == SomeFeature2StateRunning {
    /// Handles the `error` transition from Running to Stopped.
    public consuming func error(error: Error) async throws -> SomeFeature2Machine<SomeFeature2StateStopped> {
        let nextContext = try await self._errorError(self.internalContext, error)
        return SomeFeature2Machine<SomeFeature2StateStopped>(
            internalContext: nextContext,
                _start: self._start,
                _errorError: self._errorError,
                _stop: self._stop
        )
    }

    /// Handles the `stop` transition from Running to Stopped.
    public consuming func stop() async throws -> SomeFeature2Machine<SomeFeature2StateStopped> {
        let nextContext = try await self._stop(self.internalContext)
        return SomeFeature2Machine<SomeFeature2StateStopped>(
            internalContext: nextContext,
                _start: self._start,
                _errorError: self._errorError,
                _stop: self._stop
        )
    }
}

// MARK: - SomeFeature2 Combined State

/// A runtime-friendly wrapper over all observer states.
public enum SomeFeature2State: ~Copyable {
    case idle(SomeFeature2Machine<SomeFeature2StateIdle>)
    case running(SomeFeature2Machine<SomeFeature2StateRunning>)
    case stopped(SomeFeature2Machine<SomeFeature2StateStopped>)

    public init(_ machine: consuming SomeFeature2Machine<SomeFeature2StateIdle>) {
        self = .idle(machine)
    }
}

extension SomeFeature2State {
    public borrowing func withIdle<R>(_ body: (borrowing SomeFeature2Machine<SomeFeature2StateIdle>) throws -> R) rethrows -> R? {
        switch self {
        case let .idle(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withRunning<R>(_ body: (borrowing SomeFeature2Machine<SomeFeature2StateRunning>) throws -> R) rethrows -> R? {
        switch self {
        case let .running(observer):
            return try body(observer)
        default:
            return nil
        }
    }

    public borrowing func withStopped<R>(_ body: (borrowing SomeFeature2Machine<SomeFeature2StateStopped>) throws -> R) rethrows -> R? {
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

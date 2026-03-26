import Foundation
import Dependencies

// MARK: - MainFSM Typestate Markers

public enum MainFSMStateIdle {}
public enum MainFSMStateRunning {}
public enum MainFSMStateStopped {}

// How to store sub FSM in a way that don't require generics here
// We do need to be able to store the sub FSM in some way and be able to use them.
// We need to have the SomeFeature1Machine store at the same time we don't want generic
// This will be a tricky feature to add I need to really found a way abstract Generic Signature
// At the same time keep Generic properties that will enable us to always use the right
// function and not be block down the line
// Maybe we should add something like retreiving the current FSM at it current state because
// when use we want this but to store it's a nightmare.
internal struct MainFSMStateRuntimeContext: Sendable {
//  var someFeature1: SomeFeature1Machine<SomeFeature1StateIdle>
//  var someFeature2: SomeFeature2Machine<SomeFeature2StateIdle>

  init(
//    someFeature1: () -> SomeFeature1Machine<SomeFeature1StateIdle>,
//    someFeature2: () -> SomeFeature2Machine<SomeFeature2StateIdle>
  ) {
//    self.someFeature1 = someFeature1()
//    self.someFeature2 = someFeature2()
  }
}

// MARK: - MainFSM State Machine

/// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
public struct MainFSMMachine<State>: ~Copyable, Sendable {
  private var internalContext: MainFSMStateRuntimeContext
  fileprivate let _start: @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext
  fileprivate let _errorError: @Sendable (MainFSMStateRuntimeContext, Error) async throws -> MainFSMStateRuntimeContext
  fileprivate let _stop: @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext
  internal init(
    internalContext: MainFSMStateRuntimeContext,
    _start: @escaping @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext,
    _errorError: @escaping @Sendable (MainFSMStateRuntimeContext, Error) async throws -> MainFSMStateRuntimeContext,
    _stop: @escaping @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext
  ) {
    self.internalContext = internalContext
    self._start = _start
    self._errorError = _errorError
    self._stop = _stop
  }
  
  /// Access the internal context while preserving borrowing semantics.
  internal borrowing func withInternalContext<R>(_ body: (borrowing MainFSMStateRuntimeContext) throws -> R) rethrows -> R {
    try body(self.internalContext)
  }
}

// MARK: - MainFSM.Idle Transitions

extension MainFSMMachine where State == MainFSMStateIdle {
  /// Handles the `start` transition from Idle to Running.
  public consuming func start() async throws -> MainFSMMachine<MainFSMStateRunning> {
    let nextContext = try await self._start(self.internalContext)
    return MainFSMMachine<MainFSMStateRunning>(
      internalContext: nextContext,
      _start: self._start,
      _errorError: self._errorError,
      _stop: self._stop
    )
  }
}

// MARK: - MainFSM.Running Transitions

extension MainFSMMachine where State == MainFSMStateRunning {
  /// Handles the `error` transition from Running to Stopped.
  public consuming func error(error: Error) async throws -> MainFSMMachine<MainFSMStateStopped> {
    let nextContext = try await self._errorError(self.internalContext, error)
    return MainFSMMachine<MainFSMStateStopped>(
      internalContext: nextContext,
      _start: self._start,
      _errorError: self._errorError,
      _stop: self._stop
    )
  }
  
  /// Handles the `stop` transition from Running to Stopped.
  public consuming func stop() async throws -> MainFSMMachine<MainFSMStateStopped> {
    let nextContext = try await self._stop(self.internalContext)
    return MainFSMMachine<MainFSMStateStopped>(
      internalContext: nextContext,
      _start: self._start,
      _errorError: self._errorError,
      _stop: self._stop
    )
  }
}

// MARK: - MainFSM Combined State

/// A runtime-friendly wrapper over all observer states.
public enum MainFSMState: ~Copyable {
  case idle(MainFSMMachine<MainFSMStateIdle>)
  case running(MainFSMMachine<MainFSMStateRunning>)
  case stopped(MainFSMMachine<MainFSMStateStopped>)
  
  public init(_ machine: consuming MainFSMMachine<MainFSMStateIdle>) {
    self = .idle(machine)
  }
}

extension MainFSMState {
  public borrowing func withIdle<R>(_ body: (borrowing MainFSMMachine<MainFSMStateIdle>) throws -> R) rethrows -> R? {
    switch self {
      case let .idle(observer):
        return try body(observer)
      default:
        return nil
    }
  }
  
  public borrowing func withRunning<R>(_ body: (borrowing MainFSMMachine<MainFSMStateRunning>) throws -> R) rethrows -> R? {
    switch self {
      case let .running(observer):
        return try body(observer)
      default:
        return nil
    }
  }
  
  public borrowing func withStopped<R>(_ body: (borrowing MainFSMMachine<MainFSMStateStopped>) throws -> R) rethrows -> R? {
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

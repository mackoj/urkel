import Foundation
import Dependencies

// MARK: - SubFSMSomeFeature1 actor bridge for @compose
//
// Swift 6.3: actor stored properties are accessed via synthesised _read/_modify
// coroutine accessors, which prevents direct `consume`. takePhase() bypasses this
// using withUnsafeMutablePointer, returning a plain local the compiler can consume.
private actor SubFSMSomeFeature1 {
  private enum Phase: ~Copyable {
    case active(SomeFeature1State)
    case dead
  }
  private var phase: Phase

  init(_ machine: consuming SomeFeature1Machine<SomeFeature1StateIdle>) {
    phase = .active(SomeFeature1State(consume machine))
  }

  private func takePhase() -> Phase {
    withUnsafeMutablePointer(to: &phase) { ptr in
      let taken = ptr.move()
      ptr.initialize(to: .dead)
      return taken
    }
  }

  func start() async throws {
    let current = takePhase()
    switch consume current {
    case .active(let state):
      do    { phase = .active(try await state.start()) }
      catch { phase = .dead; throw error }
    case .dead: break
    }
  }

  func stop() async throws {
    let current = takePhase()
    switch consume current {
            case .active(let state):
              do    { _ = try await state.stop() }
              catch { }
    case .dead: break
    }
  }

  func error(_ err: Error) async throws {
    let current = takePhase()
    switch consume current {
            case .active(let state):
              do    { _ = try await state.error(error: err) }
              catch { }
    case .dead: break
    }
  }
}

// MARK: - SubFSMSomeFeature2 actor bridge for @compose
//
// Swift 6.3: actor stored properties are accessed via synthesised _read/_modify
// coroutine accessors, which prevents direct `consume`. takePhase() bypasses this
// using withUnsafeMutablePointer, returning a plain local the compiler can consume.
private actor SubFSMSomeFeature2 {
  private enum Phase: ~Copyable {
    case active(SomeFeature2State)
    case dead
  }
  private var phase: Phase

  init(_ machine: consuming SomeFeature2Machine<SomeFeature2StateIdle>) {
    phase = .active(SomeFeature2State(consume machine))
  }

  private func takePhase() -> Phase {
    withUnsafeMutablePointer(to: &phase) { ptr in
      let taken = ptr.move()
      ptr.initialize(to: .dead)
      return taken
    }
  }

  func start() async throws {
    let current = takePhase()
    switch consume current {
    case .active(let state):
      do    { phase = .active(try await state.start()) }
      catch { phase = .dead; throw error }
    case .dead: break
    }
  }

  func stop() async throws {
    let current = takePhase()
    switch consume current {
            case .active(let state):
              do    { _ = try await state.stop() }
              catch { }
    case .dead: break
    }
  }

  func error(_ err: Error) async throws {
    let current = takePhase()
    switch consume current {
            case .active(let state):
              do    { _ = try await state.error(error: err) }
              catch { }
    case .dead: break
    }
  }
}

// MARK: - MainFSM Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct MainFSMClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> MainFSMStateRuntimeContext
    typealias StartTransition = @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext
    typealias ErrorErrorTransition = @Sendable (MainFSMStateRuntimeContext, Error) async throws -> MainFSMStateRuntimeContext
    typealias StopTransition = @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext
    typealias MakeSomeFeature1 = @Sendable () -> SomeFeature1Machine<SomeFeature1StateIdle>
    typealias MakeSomeFeature2 = @Sendable () -> SomeFeature2Machine<SomeFeature2StateIdle>
    let initialContext: InitialContextBuilder
    let startTransition: StartTransition
    let errorErrorTransition: ErrorErrorTransition
    let stopTransition: StopTransition
    let makeSomeFeature1: MakeSomeFeature1
    let makeSomeFeature2: MakeSomeFeature2

    init(
        initialContext: @escaping InitialContextBuilder,
        startTransition: @escaping StartTransition,
        errorErrorTransition: @escaping ErrorErrorTransition,
        stopTransition: @escaping StopTransition,
        makeSomeFeature1: @escaping MakeSomeFeature1,
        makeSomeFeature2: @escaping MakeSomeFeature2
    ) {
        self.initialContext = initialContext
        self.startTransition = startTransition
        self.errorErrorTransition = errorErrorTransition
        self.stopTransition = stopTransition
        self.makeSomeFeature1 = makeSomeFeature1
        self.makeSomeFeature2 = makeSomeFeature2
    }
}

extension MainFSMClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: MainFSMClientRuntime) -> Self {
        Self(
            makeMainFSM: {
                let context = runtime.initialContext()
            let _sub1 = SubFSMSomeFeature1(runtime.makeSomeFeature1())
            let _sub2 = SubFSMSomeFeature2(runtime.makeSomeFeature2())
                return MainFSMMachine<MainFSMStateIdle>(
                    internalContext: context,
            _start: { ctx in
                try await _sub1.start()
                try await _sub2.start()
                return try await runtime.startTransition(ctx)
            },
            _errorError: { ctx, error in
                try await _sub1.error(error)
                try await _sub2.error(error)
                return try await runtime.errorErrorTransition(ctx, error)
            },
            _stop: { ctx in
                try await _sub1.stop()
                try await _sub2.stop()
                return try await runtime.stopTransition(ctx)
            }
                )
            }
        )
    }
}

// MARK: - MainFSM Client

/// Dependency client entry point for constructing MainFSM state machines.
public struct MainFSMClient: Sendable {
    public var makeMainFSM: @Sendable () -> MainFSMMachine<MainFSMStateIdle>

    public init(makeMainFSM: @escaping @Sendable () -> MainFSMMachine<MainFSMStateIdle>) {
        self.makeMainFSM = makeMainFSM
    }
}
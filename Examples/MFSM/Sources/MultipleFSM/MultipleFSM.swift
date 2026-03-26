import Foundation

// MARK: - Sub-FSM Actor Wrappers
//
// Problem: SomeFeature1Machine is ~Copyable, so it can't be shared across
// multiple @Sendable closures. Actors are Sendable and provide serial access,
// making them the right container.
//
// The .dead sentinel case is critical: Swift 6 requires that a ~Copyable stored
// property is reinitialized *before* any `await`. Setting `phase = .dead` before
// the await satisfies the compiler and acts as a safe placeholder if the actor
// is re-entered during the suspension (actors are reentrant).

//private actor SubFSM1 {
//  private enum Phase: ~Copyable {
//    case idle(SomeFeature1Machine<SomeFeature1StateIdle>)
//    case running(SomeFeature1Machine<SomeFeature1StateRunning>)
//    case dead
//  }
//
//  private var phase: Phase
//
//  init(_ machine: consuming SomeFeature1Machine<SomeFeature1StateIdle>) {
//    phase = .idle(consume machine)
//  }
//
//  // Swift 6.3 actors expose stored properties through synthesised _read/_modify
//  // coroutine accessors. `consume` requires *direct* storage, so it is rejected
//  // on actor properties ("non-storage produced by this computed property").
//  //
//  // takePhase() bypasses the accessor: withUnsafeMutablePointer reaches the raw
//  // heap storage, ptr.move() transfers ownership into a local variable, and
//  // ptr.initialize(to: .dead) leaves the property in a valid sentinel state.
//  // The caller then does `switch consume local { … }` on the local variable,
//  // which compiles fine.
//  private func takePhase() -> Phase {
//    withUnsafeMutablePointer(to: &phase) { ptr in
//      let taken = ptr.move()        // moves Phase out of actor storage
//      ptr.initialize(to: .dead)     // leaves property valid before any await
//      return taken
//    }
//  }
//
//  func start() async throws {
//    let current = takePhase()
//    switch consume current {
//    case .idle(let machine):
//      do    { phase = .running(try await machine.start()) }
//      catch { phase = .dead; throw error }
//    case .running(let machine):
//      phase = .running(machine)     // already running, restore
//    case .dead:
//      break
//    }
//  }
//
//  func stop() async throws {
//    let current = takePhase()
//    switch consume current {
//    case .running(let machine):
//      do    { _ = try await machine.stop() }
//      catch { }
//      // phase stays .dead — machine has been consumed
//    case .idle(let machine):
//      phase = .idle(machine)        // never started, restore
//    case .dead:
//      break
//    }
//  }
//
//  func error(_ err: Error) async throws {
//    let current = takePhase()
//    switch consume current {
//    case .running(let machine):
//      do    { _ = try await machine.error(error: err) }
//      catch { }
//      // phase stays .dead
//    case .idle(let machine):
//      phase = .idle(machine)        // not started, restore
//    case .dead:
//      break
//    }
//  }
//}

// MARK: - MainFSMClient Live

//extension MainFSMClient {
//  static func makeLive() -> Self {
//    // Each actor owns one sub-machine and is Sendable, so it can be safely
//    // captured across the three @Sendable transition closures below.
//    let feature1 = SubFSM1(SomeFeature1Client.makeLive().makeSomeFeature1())
//    // let feature2 = SubFSM2(SomeFeature2Client.makeLive().makeSomeFeature2())
//
//    return Self {
//      MainFSMMachine<MainFSMStateIdle>(
//        internalContext: MainFSMStateRuntimeContext(),
//        _start: { ctx in
//          print("Start MainFSMMachine")
//          try await feature1.start()
//          return ctx
//        },
//        _errorError: { ctx, error in
//          print("Error MainFSMMachine")
//          try await feature1.error(error)
//          return ctx
//        },
//        _stop: { ctx in
//          print("Stop MainFSMMachine")
//          try await feature1.stop()
//          return ctx
//        }
//      )
//    }
//  }
//}
//
//extension SomeFeature2Client {
//  static func makeLive() -> Self {
//    Self {
//      SomeFeature2Machine<SomeFeature2StateIdle>(
//        internalContext: SomeFeature2StateRuntimeContext()) { ctx in
//          print("Start SomeFeature2Machine")
//          return SomeFeature2StateRuntimeContext()
//      } _errorError: { ctx, error in
//        print("Error SomeFeature2Machine")
//        return SomeFeature2StateRuntimeContext()
//      } _stop: { ctx in
//        print("Stop SomeFeature2Machine")
//        return SomeFeature2StateRuntimeContext()
//      }
//    }
//  }
//}
//
//extension SomeFeature1Client {
//  static func makeLive() -> Self {
//    Self {
//      SomeFeature1Machine<SomeFeature1StateIdle>(
//        internalContext: SomeFeature1StateRuntimeContext()) { ctx in
//          print("Start SomeFeature1Machine")
//          return SomeFeature1StateRuntimeContext()
//      } _errorError: { ctx, error in
//        print("Error SomeFeature1Machine")
//        return SomeFeature1StateRuntimeContext()
//      } _stop: { ctx in
//        print("Stop SomeFeature1Machine")
//        return SomeFeature1StateRuntimeContext()
//      }
//
//    }
//  }
//}

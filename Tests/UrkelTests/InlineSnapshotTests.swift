import Testing
import Urkel

@Suite("Inline snapshots")
struct InlineSnapshotTests {
    @Test("Parser snapshot for Bluetooth example")
    func bluetoothAstSnapshot() throws {
        let source = """
        machine Bluetooth
        @compose BLE
        @factory makeBlender()
        @states
          init Disconnected
          state Scanning
          state Connecting
          state Connected
          final Error
        @transitions
          Disconnected -> startScan -> Scanning
          Scanning -> deviceFound(device: CBPeripheral) -> Connecting
          Scanning -> timeout -> Disconnected
          Connecting -> connectSuccess -> Connected
          Connecting -> connectFail(error: Error) -> Error
          Connected -> disconnect -> Disconnected
        """

        let ast = try UrkelParser().parse(source: source)
        assertMachine(ast) {
            """
            machine Bluetooth
            imports: 
            compose: BLE
            @factory makeBlender()
            @states
              init Disconnected
              state Scanning
              state Connecting
              state Connected
              final Error
            @transitions
              Disconnected -> startScan -> Scanning
              Scanning -> deviceFound(device: CBPeripheral) -> Connecting
              Scanning -> timeout -> Disconnected
              Connecting -> connectSuccess -> Connected
              Connecting -> connectFail(error: Error) -> Error
              Connected -> disconnect -> Disconnected
            """
        }
    }

    @Test("Swift emission snapshot for FolderWatch")
    func swiftEmissionSnapshot() {
        let ast = makeFolderWatchAST()
        let output = SwiftCodeEmitter().emitUnified(ast: ast)
        assertSwiftEmission(output) {
            """
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
                private var internalContext: FolderContext

                private let _start: @Sendable (FolderContext) async throws -> FolderContext
                private let _stop: @Sendable (FolderContext) async throws -> FolderContext
                public init(
                    internalContext: FolderContext,
                    _start: @escaping @Sendable (FolderContext) async throws -> FolderContext,
                    _stop: @escaping @Sendable (FolderContext) async throws -> FolderContext
                ) {
                    self.internalContext = internalContext

                    self._start = _start
                    self._stop = _stop
                }

                /// Access the internal context while preserving borrowing semantics.
                public borrowing func withInternalContext<R>(_ body: (borrowing FolderContext) throws -> R) rethrows -> R {
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

            import Foundation
            import Dependencies

            // MARK: - FolderWatch Runtime Builder

            /// Runtime transition hooks used to construct a machine observer without editing generated code.
            struct FolderWatchClientRuntime {
                typealias InitialContextBuilder = @Sendable (URL, Int) -> FolderContext
                typealias StartTransition = @Sendable (FolderContext) async throws -> FolderContext
                typealias StopTransition = @Sendable (FolderContext) async throws -> FolderContext
                let initialContext: InitialContextBuilder
                let startTransition: StartTransition
                let stopTransition: StopTransition

                init(
                    initialContext: @escaping InitialContextBuilder,
                    startTransition: @escaping StartTransition,
                    stopTransition: @escaping StopTransition
                ) {
                    self.initialContext = initialContext
                    self.startTransition = startTransition
                    self.stopTransition = stopTransition
                }
            }

            extension FolderWatchClient {
                /// Builds a client factory from explicit runtime transition hooks.
                static func fromRuntime(_ runtime: FolderWatchClientRuntime) -> Self {
                    Self(
                        makeObserver: { directory, debounceMs in
                            let context = runtime.initialContext(directory, debounceMs)
                            return FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>(
                                internalContext: context,
                            _start: runtime.startTransition,
                            _stop: runtime.stopTransition
                            )
                        }
                    )
                }
            }

            // MARK: - FolderWatch Client

            /// Dependency client entry point for constructing FolderWatch state machines.
            public struct FolderWatchClient: Sendable {
                public var makeObserver: @Sendable (URL, Int) -> FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>

                public init(makeObserver: @escaping @Sendable (URL, Int) -> FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>) {
                    self.makeObserver = makeObserver
                }
            }

            import Foundation
            import Dependencies

            extension FolderWatchClient: DependencyKey {
                public static let testValue = Self(
                    makeObserver: {
                                _, _ in fatalError("Configure FolderWatchClient.testValue in tests.")
                            }
                )

                public static let previewValue = Self(
                    makeObserver: {
                                _, _ in fatalError("Configure FolderWatchClient.previewValue in previews.")
                            }
                )

                /// The live production implementation.
                /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
                public static var liveValue: Self { .makeLive() }
            }

            extension DependencyValues {
                /// Accessor for the generated FolderWatchClient dependency.
                public var folderWatch: FolderWatchClient {
                    get { self[FolderWatchClient.self] }
                    set { self[FolderWatchClient.self] = newValue }
                }
            }
            """
        }
    }

    @Test("Parser round-trip print snapshot")
    func parserRoundTripPrintSnapshot() throws {
        let source = """
        machine  Bluetooth
        @compose BLE
        @factory   makeObserver( url : URL , debounceMs : Int )
        @states
          init    Idle
             state Running
          final Stopped
        @transitions
           Idle  ->   start  ->   Running
        Running->stop( reason : String )->Stopped
        """

        let parser = UrkelParser()
        let ast = try parser.parse(source: source)
        let roundTrip = parser.print(ast: ast)
        assertSwiftEmission(roundTrip) {
            """
            machine Bluetooth
            @compose BLE
            @factory makeObserver(url: URL, debounceMs: Int)
            @states
              init Idle
              state Running
              final Stopped
            @transitions
              Idle -> start -> Running
              Running -> stop(reason: String) -> Stopped
            """
        }
    }
}

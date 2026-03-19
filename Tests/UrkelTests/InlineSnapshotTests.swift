import Testing
import Urkel

@Suite("Inline snapshots")
struct InlineSnapshotTests {
    @Test("Parser snapshot for Bluetooth example")
    func bluetoothAstSnapshot() throws {
        let source = """
        @imports
          import CoreBluetooth
          import Dependencies

        machine Bluetooth
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
            imports: CoreBluetooth, Dependencies
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
        let output = UrkelEmitter().emit(ast: ast)
        assertSwiftEmission(output) {
            """
            import Foundation
            import Dependencies

            public enum Idle {}
            public enum Running {}
            public enum Stopped {}

            public struct FolderWatchObserver<State>: ~Copyable {
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
            }

            extension FolderWatchObserver where State == Idle {
                public consuming func start() async throws -> FolderWatchObserver<Running> {
                    let nextContext = try await self._start(self.internalContext)
                    return FolderWatchObserver<Running>(
                        internalContext: nextContext,
                            _start: self._start,
                            _stop: self._stop
                    )
                }
            }

            extension FolderWatchObserver where State == Running {
                public consuming func stop() async throws -> FolderWatchObserver<Stopped> {
                    let nextContext = try await self._stop(self.internalContext)
                    return FolderWatchObserver<Stopped>(
                        internalContext: nextContext,
                            _start: self._start,
                            _stop: self._stop
                    )
                }
            }

            public enum FolderWatchState: ~Copyable {
                case idle(FolderWatchObserver<Idle>)
                case running(FolderWatchObserver<Running>)
                case stopped(FolderWatchObserver<Stopped>)

                public init(_ observer: consuming FolderWatchObserver<Idle>) {
                    self = .idle(observer)
                }
            }

            extension FolderWatchState {
                public borrowing func withIdle<R>(_ body: (borrowing FolderWatchObserver<Idle>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .idle(observer):
                        return try body(observer)

                    case .running:
                        return nil
                    case .stopped:
                        return nil
                    }
                }

                public borrowing func withRunning<R>(_ body: (borrowing FolderWatchObserver<Running>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .running(observer):
                        return try body(observer)

                    case .idle:
                        return nil
                    case .stopped:
                        return nil
                    }
                }

                public borrowing func withStopped<R>(_ body: (borrowing FolderWatchObserver<Stopped>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .stopped(observer):
                        return try body(observer)

                    case .idle:
                        return nil
                    case .running:
                        return nil
                    }
                }


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

            public struct FolderWatchClient: Sendable {
                public var makeObserver: @Sendable (URL, Int) -> FolderWatchObserver<Idle>

                public init(makeObserver: @escaping @Sendable (URL, Int) -> FolderWatchObserver<Idle>) {
                    self.makeObserver = makeObserver
                }
            }

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

                public static let liveValue = Self(
                    makeObserver: {
                                _, _ in fatalError("Configure FolderWatchClient.liveValue in your app target.")
                            }
                )
            }

            extension DependencyValues {
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
        @imports
         import Foundation
           import Dependencies

        machine  Bluetooth
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
            @imports
              import Foundation
              import Dependencies

            machine Bluetooth
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

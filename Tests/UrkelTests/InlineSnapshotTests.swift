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

            public struct FolderWatchClient: Sendable {
                public var makeObserver: @Sendable (URL, Int) -> FolderWatchObserver<Idle>

                public init(makeObserver: @escaping @Sendable (URL, Int) -> FolderWatchObserver<Idle>) {
                    self.makeObserver = makeObserver
                }
            }

            extension FolderWatchClient: TestDependencyKey {
                public static let testValue = Self(
                    makeObserver: { _, _ in 
                        fatalError("Configure FolderWatchClient.testValue in tests.")
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
}

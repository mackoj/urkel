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
        let output = SwiftCodeEmitter().emit(ast: ast)
        assertSwiftEmission(output) {
            """
            import Foundation
            import Dependencies

            // MARK: - FolderWatch State Machine

            /// Typestate markers for the `FolderWatch` machine.
            public enum FolderWatchMachine {
                public enum Idle {}
                public enum Running {}
                public enum Stopped {}
            }

            // MARK: - FolderWatch Runtime Context Bridge

            /// Internal state-aware context wrapper used by generated runtime helpers.
            struct FolderWatchRuntimeContext: Sendable {
                enum Storage: Sendable {
                    case idle(FolderContext)
                    case running(FolderContext)
                    case stopped(FolderContext)
                }

                let storage: Storage

                init(storage: Storage) {
                    self.storage = storage
                }

            static func idle(_ value: FolderContext) -> Self {
                .init(storage: .idle(value))
            }

            static func running(_ value: FolderContext) -> Self {
                .init(storage: .running(value))
            }

            static func stopped(_ value: FolderContext) -> Self {
                .init(storage: .stopped(value))
            }
            }

            // MARK: - FolderWatch Observer

            /// A type-safe observer wrapper that encodes the current machine state in its generic parameter.
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

                /// Access the internal context while preserving borrowing semantics.
                public borrowing func withInternalContext<R>(_ body: (borrowing FolderContext) throws -> R) rethrows -> R {
                    try body(self.internalContext)
                }
            }

            // MARK: - FolderWatch Runtime Stream

            /// Generic stream lifecycle helper for event-driven runtimes generated from this machine.
            actor FolderWatchRuntimeStream<Element: Sendable> {
                nonisolated let events: AsyncThrowingStream<Element, Error>

                private var continuation: AsyncThrowingStream<Element, Error>.Continuation?
                private var pendingEvent: Element?
                private var debounceTask: Task<Void, Never>?
                private let debounceMs: Int

                init(debounceMs: Int = 0) {
                    self.debounceMs = max(0, debounceMs)

                    var capturedContinuation: AsyncThrowingStream<Element, Error>.Continuation?
                    self.events = AsyncThrowingStream<Element, Error> { continuation in
                        capturedContinuation = continuation
                    }
                    self.continuation = capturedContinuation
                }

                func emit(_ event: Element) {
                    guard let continuation else { return }

                    if debounceMs == 0 {
                        continuation.yield(event)
                        return
                    }

                    pendingEvent = event
                    debounceTask?.cancel()
                    debounceTask = Task { [debounceMs] in
                        try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
                        self.flushPendingEvent()
                    }
                }

                func finish(throwing error: Error? = nil) {
                    debounceTask?.cancel()
                    debounceTask = nil
                    pendingEvent = nil
                    continuation?.finish(throwing: error)
                    continuation = nil
                }

                private func flushPendingEvent() {
                    guard let event = pendingEvent else { return }
                    pendingEvent = nil
                    continuation?.yield(event)
                }
            }

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
                        makeObserver: { directory: URL, debounceMs: Int in
                            let context = runtime.initialContext(directory, debounceMs)
                            return FolderWatchObserver<FolderWatchMachine.Idle>(
                                internalContext: context,
                            _start: runtime.startTransition,
                            _stop: runtime.stopTransition
                            )
                        }
                    )
                }
            }

            // MARK: - FolderWatch.Idle Transitions

            extension FolderWatchObserver where State == FolderWatchMachine.Idle {
                /// Handles the `start` transition from Idle to Running.
                public consuming func start() async throws -> FolderWatchObserver<FolderWatchMachine.Running> {
                    let nextContext = try await self._start(self.internalContext)
                    return FolderWatchObserver<FolderWatchMachine.Running>(
                        internalContext: nextContext,
                            _start: self._start,
                            _stop: self._stop
                    )
                }
            }

            // MARK: - FolderWatch.Running Transitions

            extension FolderWatchObserver where State == FolderWatchMachine.Running {
                /// Handles the `stop` transition from Running to Stopped.
                public consuming func stop() async throws -> FolderWatchObserver<FolderWatchMachine.Stopped> {
                    let nextContext = try await self._stop(self.internalContext)
                    return FolderWatchObserver<FolderWatchMachine.Stopped>(
                        internalContext: nextContext,
                            _start: self._start,
                            _stop: self._stop
                    )
                }
            }

            // MARK: - FolderWatch Combined State

            /// A runtime-friendly wrapper over all observer states.
            public enum FolderWatchState: ~Copyable {
                case idle(FolderWatchObserver<FolderWatchMachine.Idle>)
                case running(FolderWatchObserver<FolderWatchMachine.Running>)
                case stopped(FolderWatchObserver<FolderWatchMachine.Stopped>)

                public init(_ observer: consuming FolderWatchObserver<FolderWatchMachine.Idle>) {
                    self = .idle(observer)
                }
            }

            extension FolderWatchState {
                public borrowing func withIdle<R>(_ body: (borrowing FolderWatchObserver<FolderWatchMachine.Idle>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .idle(observer):
                        return try body(observer)

                    case .running:
                        return nil
                    case .stopped:
                        return nil
                    }
                }

                public borrowing func withRunning<R>(_ body: (borrowing FolderWatchObserver<FolderWatchMachine.Running>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .running(observer):
                        return try body(observer)

                    case .idle:
                        return nil
                    case .stopped:
                        return nil
                    }
                }

                public borrowing func withStopped<R>(_ body: (borrowing FolderWatchObserver<FolderWatchMachine.Stopped>) throws -> R) rethrows -> R? {
                    switch self {
                    case let .stopped(observer):
                        return try body(observer)

                    case .idle:
                        return nil
                    case .running:
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

            // MARK: - FolderWatch Client

            /// Dependency client entry point for constructing FolderWatch observers.
            public struct FolderWatchClient: Sendable {
                public var makeObserver: @Sendable (URL, Int) -> FolderWatchObserver<FolderWatchMachine.Idle>

                public init(makeObserver: @escaping @Sendable (URL, Int) -> FolderWatchObserver<FolderWatchMachine.Idle>) {
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

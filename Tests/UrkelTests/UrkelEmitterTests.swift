import Foundation
import Testing
@testable import Urkel

@Suite("US 4.1 + 4.2 + 4.3 + 4.4 + 4.5 - Emitter")
struct SwiftCodeEmitterTests {
    @Test("Emitter includes imports, states, observer and client")
    func emitsCoreSections() {
        let ast = makeFolderWatchAST()
        let output = SwiftCodeEmitter().emitUnified(ast: ast)

        #expect(output.contains("import Foundation"))
        #expect(output.contains("public enum FolderWatchStateIdle {}"))
        #expect(!output.contains("struct FolderWatchRuntimeContext: Sendable"))
        #expect(output.contains("public struct FolderWatchMachine<State>: ~Copyable"))
        #expect(!output.contains("actor FolderWatchRuntimeStream<Element: Sendable>"))
        #expect(output.contains("struct FolderWatchClientRuntime"))
        #expect(output.contains("public struct FolderWatchClient: Sendable"))
        #expect(output.contains("extension DependencyValues"))
    }

    @Test("Swift emitter supports import override")
    func swiftImportOverride() {
        let ast = makeFolderWatchAST()
        let output = SwiftCodeEmitter().emitUnified(ast: ast, swiftImportsOverride: ["Foundation", "CustomSDK"])
        #expect(output.contains("import CustomSDK"))
        #expect(output.contains("import Dependencies"))
        #expect(output.contains("import Foundation"))
    }

    @Test("Emitter groups transitions by source state and emits consuming funcs")
    func emitsGroupedTransitionExtensions() {
        let ast = MachineAST(
            imports: ["Foundation"],
            machineName: "Bluetooth",
            contextType: "BluetoothContext",
            factory: .init(name: "makeObserver", parameters: []),
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Scanning", kind: .normal),
                .init(name: "Error", kind: .terminal)
            ],
            transitions: [
                .init(from: "Idle", event: "start", parameters: [], to: "Scanning"),
                .init(from: "Idle", event: "fail", parameters: [], to: "Error"),
                .init(from: "Scanning", event: "found", parameters: [.init(name: "device", type: "Peripheral")], to: "Idle")
            ]
        )

        let output = SwiftCodeEmitter().emitUnified(ast: ast)
        #expect(output.contains("extension BluetoothMachine where State == BluetoothStateIdle"))
        #expect(output.contains("public consuming func start() async throws -> BluetoothMachine<BluetoothStateScanning>"))
        #expect(output.contains("public consuming func fail() async throws -> BluetoothMachine<BluetoothStateError>"))
        #expect(output.contains("public consuming func found(device: Peripheral) async throws -> BluetoothMachine<BluetoothStateIdle>"))
    }

    @Test("Emitter keeps distinct transition closures for same event with different payloads")
    func distinctClosureNamesForEventOverloads() {
        let ast = MachineAST(
            imports: ["Foundation", "Dependencies"],
            machineName: "Overloaded",
            contextType: "String",
            factory: .init(name: "makeObserver", parameters: []),
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal),
                .init(name: "Errored", kind: .terminal),
            ],
            transitions: [
                .init(from: "Idle", event: "connect", parameters: [], to: "Running"),
                .init(from: "Running", event: "connect", parameters: [.init(name: "error", type: "Error")], to: "Errored"),
            ]
        )

        let output = SwiftCodeEmitter().emitUnified(ast: ast)
        #expect(output.contains("private let _connect: @Sendable (String) async throws -> String"))
        #expect(output.contains("private let _connectError: @Sendable (String, Error) async throws -> String"))
        #expect(output.contains("let connectTransition: ConnectTransition"))
        #expect(output.contains("let connectErrorTransition: ConnectErrorTransition"))
        #expect(output.contains("let context = runtime.initialContext()"))
    }

    @Test("Emitter includes runtime scaffolding wrapper and unwrapping")
    func emitsRuntimeScaffolding() {
        let output = SwiftCodeEmitter().emitUnified(ast: makeFolderWatchAST())

        #expect(output.contains("// MARK: - FolderWatch Combined State"))
        #expect(output.contains("public enum FolderWatchState: ~Copyable"))
        #expect(output.contains("case idle(FolderWatchMachine<FolderWatchStateIdle>)"))
        #expect(output.contains("public borrowing func withRunning<R>(_ body: (borrowing FolderWatchMachine<FolderWatchStateRunning>) throws -> R) rethrows -> R?"))
        #expect(output.contains("/// Attempts the `start` transition from the current wrapper state."))
        #expect(output.contains("public consuming func start() async throws -> Self"))
        #expect(output.contains("public consuming func stop() async throws -> Self"))
    }

    @Test("Emitter includes dependency defaults for preview/test/live")
    func emitsDependencyDefaults() {
        let output = SwiftCodeEmitter().emitUnified(ast: makeFolderWatchAST())

        #expect(output.contains("// MARK: - FolderWatch Client"))
        #expect(output.contains("public static let testValue = Self("))
        #expect(output.contains("public static let previewValue = Self("))
        #expect(output.contains("public static var liveValue: Self { .makeLive() }"))
    }

    @Test("Emitter embeds sub-observer slot and factory for composed machines")
    func emitsSubObserverEmbeddingForComposition() {
        let ast = MachineAST(
            imports: ["Foundation", "Dependencies"],
            machineName: "Scale",
            contextType: "ScaleContext",
            factory: .init(name: "makeScaleObserver", parameters: []),
            composedMachines: ["BLE"],
            states: [
                .init(name: "WakingUp", kind: .initial),
                .init(name: "Tare", kind: .normal),
                .init(name: "Done", kind: .terminal),
            ],
            transitions: [
                .init(from: "WakingUp", event: "hardwareReady", parameters: [], to: "Tare", spawnedMachine: "BLE"),
                .init(from: "Tare", event: "finish", parameters: [], to: "Done")
            ]
        )

        let output = SwiftCodeEmitter().emitUnified(ast: ast)

        // Sub-observer slot and factory are embedded in the observer
        #expect(output.contains("var _bleState: BLEState?"))
        #expect(output.contains("let _makeBLE: @Sendable () -> BLEState"))

        // No orchestrator actor generated
        #expect(!output.contains("public actor ScaleOrchestrator"))

        // Fork transition spawns BLE using factory
        #expect(output.contains("_bleState: self._makeBLE()"))

        // Non-fork transitions carry composed state forward
        #expect(output.contains("_bleState: self._bleState"))

        // Client factory accepts BLE factory parameter
        #expect(output.contains("@Sendable (@escaping @Sendable () -> BLEState) -> ScaleMachine<ScaleStateWakingUp>"))

        // fromRuntime closure accepts makeBLE parameter
        #expect(output.contains("makeScaleObserver: { makeBLE in"))

        // fromRuntime passes _makeBLE to observer (bleState uses default .none)
        #expect(!output.contains("_bleState: nil"))
        #expect(output.contains("_makeBLE: makeBLE"))

        // Placeholder closures ignore composed factory param
        #expect(output.contains("makeScaleObserver: {"))
    }

    @Test("Emitter generates ~Escapable conformance when nonescapable is true")
    func emitsNonescapableConformance() {
        let ast = makeFolderWatchAST()
        let output = SwiftCodeEmitter().emitUnified(ast: ast, nonescapable: true)
        #expect(output.contains("public struct FolderWatchMachine<State>: ~Copyable, ~Escapable"))
    }

    @Test("Emitter generates BLE forwarding methods when composed AST is provided")
    func emitsComposedForwardingMethods() {
        let bleAST = MachineAST(
            imports: ["Foundation"],
            machineName: "BLE",
            contextType: "BLEContext",
            factory: .init(name: "makeBLE", parameters: []),
            states: [
                .init(name: "Off", kind: .initial),
                .init(name: "Scanning", kind: .normal),
                .init(name: "Connected", kind: .terminal),
            ],
            transitions: [
                .init(from: "Off", event: "powerOn", parameters: [], to: "Scanning"),
                .init(from: "Scanning", event: "deviceFound", parameters: [.init(name: "device", type: "String")], to: "Connected")
            ]
        )
        let scaleAST = MachineAST(
            imports: ["Foundation"],
            machineName: "Scale",
            contextType: "ScaleContext",
            factory: .init(name: "makeScale", parameters: []),
            composedMachines: ["BLE"],
            states: [
                .init(name: "WakingUp", kind: .initial),
                .init(name: "Tare", kind: .normal),
                .init(name: "Done", kind: .terminal),
            ],
            transitions: [
                .init(from: "WakingUp", event: "hardwareReady", parameters: [], to: "Tare", spawnedMachine: "BLE"),
                .init(from: "Tare", event: "finish", parameters: [], to: "Done")
            ]
        )

        let output = SwiftCodeEmitter().emitUnified(ast: scaleAST, composedASTs: ["BLE": bleAST])

        // BLE forwarding extension on ScaleState
        #expect(output.contains("extension ScaleState {"))
        // blePowerOn with no params
        #expect(output.contains("public consuming func blePowerOn() async throws -> Self"))
        // bleDeviceFound with params
        #expect(output.contains("public consuming func bleDeviceFound(device: String) async throws -> Self"))
        // Post-fork states use the advance helper
        #expect(output.contains("case let .tare(obs):"))
        #expect(output.contains("obs._advancingBLEState"))
        // Pre-fork states pass through unchanged
        #expect(output.contains("case let .wakingUp(obs):"))
        // No forwarding generated without composed AST
        let outputWithoutAST = SwiftCodeEmitter().emitUnified(ast: scaleAST, composedASTs: [:])
        #expect(!outputWithoutAST.contains("func blePowerOn"))
    }

    @Test("Emitter withXxx methods use switch with default for clean borrowing")
    func emitsWithMethodsUsingSwitch() {
        let output = SwiftCodeEmitter().emitUnified(ast: makeFolderWatchAST())
        #expect(output.contains("public borrowing func withRunning<R>(_ body: (borrowing FolderWatchMachine<FolderWatchStateRunning>) throws -> R) rethrows -> R?"))
        #expect(output.contains("default:"))
        #expect(output.contains("return nil"))
    }

    @Test("Emitter normalizes lowercase machine names to PascalCase symbols")
    func normalizesLowercaseMachineName() {
        let ast = MachineAST(
            imports: ["Foundation"],
            machineName: "folderwatch",
            contextType: "FolderContext",
            factory: .init(name: "makeObserver", parameters: [.init(name: "directory", type: "URL"), .init(name: "debounceMs", type: "Int")]),
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal),
                .init(name: "Stopped", kind: .terminal)
            ],
            transitions: [
                .init(from: "Idle", event: "start", parameters: [], to: "Running"),
                .init(from: "Running", event: "stop", parameters: [], to: "Stopped")
            ]
        )

        let output = SwiftCodeEmitter().emitUnified(ast: ast)
        #expect(output.contains("public struct FolderWatchMachine<State>: ~Copyable"))
        #expect(output.contains("public struct FolderWatchClient: Sendable"))
        #expect(output.contains("public enum FolderWatchState: ~Copyable"))
        #expect(output.contains("public var folderWatch: FolderWatchClient"))
    }

    @Test("Emitter namespaces states to avoid machine collisions")
    func namespacesStatesAcrossMachines() {
        let lhs = SwiftCodeEmitter().emitUnified(ast: makeFolderWatchAST(machineName: "FolderWatch"))
        let rhs = SwiftCodeEmitter().emitUnified(ast: makeFolderWatchAST(machineName: "Bluetooth"))
        let combined = lhs + "\n\n" + rhs

        #expect(combined.contains("public struct FolderWatchMachine<State>: ~Copyable"))
        #expect(combined.contains("public struct BluetoothMachine<State>: ~Copyable"))
        #expect(!combined.contains("public enum Idle {}\npublic enum Running {}\npublic enum Stopped {}"))
    }

    @Test("Emitter uses typed runtime context when machine context is omitted")
    func emitsTypedRuntimeContextFallback() {
        let ast = MachineAST(
            imports: ["Foundation"],
            machineName: "NoContext",
            contextType: nil,
            factory: .init(name: "makeObserver", parameters: []),
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal)
            ],
            transitions: [
                .init(from: "Idle", event: "start", parameters: [], to: "Running")
            ]
        )

        let output = SwiftCodeEmitter().emitUnified(ast: ast)
        #expect(output.contains("public struct NoContextMachine<State>: ~Copyable"))
        #expect(output.contains("public struct NoContextStateRuntimeContext: Sendable {"))
        #expect(!output.contains("struct NoContextRuntimeContext: Sendable"))
        #expect(output.contains("private var internalContext: NoContextStateRuntimeContext"))
    }

    @Test("Emitter passes state and transition comments through as Swift doc comments")
    func emitsDocCommentsFromParserNodes() {
        let ast = MachineAST(
            imports: ["Foundation", "Dependencies"],
            machineName: "Commented",
            contextType: "String",
            factory: .init(name: "makeObserver", parameters: []),
            states: [
                .init(name: "Idle", kind: .initial, docComments: [.init(text: "Initial idle state")]),
                .init(name: "Running", kind: .normal)
            ],
            transitions: [
                .init(
                    from: "Idle",
                    event: "start",
                    parameters: [],
                    to: "Running",
                    docComments: [.init(text: "Starts the runtime observer")]
                )
            ]
        )

        let output = SwiftCodeEmitter().emitUnified(ast: ast)
        #expect(output.contains("/// Initial idle state\npublic enum CommentedStateIdle {}"))
        #expect(output.contains("/// Starts the runtime observer"))
        #expect(!output.contains("/// Handles the `start` transition from Idle to Running."))
    }

    @Test("Generated Swift compiles in an integration package")
    func generatedSwiftCompiles() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let packageDir = root.appendingPathComponent("CompileFixture")
        let sourcesDir = packageDir.appendingPathComponent("Sources/App")
        try fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)

        let ast = MachineAST(
            imports: ["Foundation", "Dependencies"],
            machineName: "CompileMachine",
            contextType: "String",
            factory: .init(name: "makeObserver", parameters: []),
            states: [
                .init(name: "Idle", kind: .initial),
                .init(name: "Running", kind: .normal)
            ],
            transitions: [
                .init(from: "Idle", event: "start", parameters: [], to: "Running")
            ]
        )

        let generated = SwiftCodeEmitter().emitUnified(ast: ast)

        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "CompileFixture",
            platforms: [.macOS(.v13)],
            dependencies: [
                .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0")
            ],
            targets: [
                .executableTarget(
                    name: "App",
                    dependencies: [.product(name: "Dependencies", package: "swift-dependencies")]
                )
            ]
        )
        """.write(to: packageDir.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        // Provide the required makeLive() implementation that liveValue references.
        let liveStub = """
        extension CompileMachineClient {
            public static func makeLive() -> Self { .noop }
        }
        """
        try (generated + "\n\n" + liveStub + "\n\nprint(\"ok\")\n").write(
            to: sourcesDir.appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )

        let result = try runProcess("/usr/bin/env", ["swift", "build"], cwd: packageDir)
        #expect(result.0 == 0, "\(result.1)\n\(result.2)")
    }

    @Test("Closure-captured mode emits stored properties instead of context")
    func closureCapturedModeEmitsStoredProperties() throws {
        let source = """
        machine folderwatch
        @factory makeObserver(directory: URL, debounceMs: Int)
        @states
          init Idle
          state Running
          final Stopped
        @transitions
          Idle -> start -> Running
          Running -> events
          Running -> stop -> Stopped
        @continuation
          events -> AsyncThrowingStream<DirectoryEvent, Error>
        """
        let ast = try UrkelParser().parse(source: source)
        let files = SwiftCodeEmitter().emit(ast: ast)

        #expect(files.stateMachine.contains("public let directory: URL"))
        #expect(files.stateMachine.contains("public let debounceMs: Int"))
        #expect(!files.stateMachine.contains("withInternalContext"))
        #expect(files.stateMachine.contains("where State == FolderWatchStateIdle"))
        #expect(files.stateMachine.contains("where State == FolderWatchStateRunning"))
        #expect(files.stateMachine.contains("public var events: AsyncThrowingStream<DirectoryEvent, Error>"))
        #expect(!files.stateMachine.contains("consuming func events"))
        #expect(!files.client.contains("ClientRuntime"))
        #expect(!files.client.contains("fromRuntime"))
        #expect(files.client.contains("noop"))
    }
}

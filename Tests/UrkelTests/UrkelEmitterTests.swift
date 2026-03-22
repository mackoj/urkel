import Foundation
import Testing
@testable import Urkel

@Suite("US 4.1 + 4.2 + 4.3 + 4.4 + 4.5 - Emitter")
struct SwiftCodeEmitterTests {
    @Test("Emitter includes imports, states, observer and client")
    func emitsCoreSections() {
        let ast = makeFolderWatchAST()
        let output = SwiftCodeEmitter().emit(ast: ast)

        #expect(output.contains("import Foundation"))
        #expect(output.contains("public enum FolderWatchMachine {"))
        #expect(output.contains("public enum Idle {}"))
        #expect(output.contains("struct FolderWatchRuntimeContext: Sendable"))
        #expect(output.contains("public struct FolderWatchObserver<State>: ~Copyable"))
        #expect(output.contains("actor FolderWatchRuntimeStream<Element: Sendable>"))
        #expect(output.contains("struct FolderWatchClientRuntime"))
        #expect(output.contains("public struct FolderWatchClient: Sendable"))
        #expect(output.contains("extension DependencyValues"))
    }

    @Test("Swift emitter supports import override")
    func swiftImportOverride() {
        let ast = makeFolderWatchAST()
        let output = SwiftCodeEmitter().emit(ast: ast, swiftImportsOverride: ["Foundation", "CustomSDK"])
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

        let output = SwiftCodeEmitter().emit(ast: ast)
        #expect(output.contains("extension BluetoothObserver where State == BluetoothMachine.Idle"))
        #expect(output.contains("public consuming func start() async throws -> BluetoothObserver<BluetoothMachine.Scanning>"))
        #expect(output.contains("public consuming func fail() async throws -> BluetoothObserver<BluetoothMachine.Error>"))
        #expect(output.contains("public consuming func found(device: Peripheral) async throws -> BluetoothObserver<BluetoothMachine.Idle>"))
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

        let output = SwiftCodeEmitter().emit(ast: ast)
        #expect(output.contains("private let _connect: @Sendable (String) async throws -> String"))
        #expect(output.contains("private let _connectErrorError: @Sendable (String, Error) async throws -> String"))
        #expect(output.contains("let connectTransition: ConnectTransition"))
        #expect(output.contains("let connectErrorErrorTransition: ConnectErrorErrorTransition"))
        #expect(output.contains("let context = runtime.initialContext()"))
    }

    @Test("Emitter includes runtime scaffolding wrapper and unwrapping")
    func emitsRuntimeScaffolding() {
        let output = SwiftCodeEmitter().emit(ast: makeFolderWatchAST())

        #expect(output.contains("// MARK: - FolderWatch Combined State"))
        #expect(output.contains("public enum FolderWatchState: ~Copyable"))
        #expect(output.contains("case idle(FolderWatchObserver<FolderWatchMachine.Idle>)"))
        #expect(output.contains("public borrowing func withRunning<R>(_ body: (borrowing FolderWatchObserver<FolderWatchMachine.Running>) throws -> R) rethrows -> R?"))
        #expect(output.contains("/// Attempts the `start` transition from the current wrapper state."))
        #expect(output.contains("public consuming func start() async throws -> Self"))
        #expect(output.contains("public consuming func stop() async throws -> Self"))
    }

    @Test("Emitter includes dependency defaults for preview/test/live")
    func emitsDependencyDefaults() {
        let output = SwiftCodeEmitter().emit(ast: makeFolderWatchAST())

        #expect(output.contains("// MARK: - FolderWatch Client"))
        #expect(output.contains("public static let testValue = Self("))
        #expect(output.contains("public static let previewValue = Self("))
        #expect(output.contains("public static let liveValue = Self("))
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

        let output = SwiftCodeEmitter().emit(ast: ast)
        #expect(output.contains("public struct FolderWatchObserver<State>: ~Copyable"))
        #expect(output.contains("public struct FolderWatchClient: Sendable"))
        #expect(output.contains("public enum FolderWatchMachine {"))
        #expect(output.contains("public enum FolderWatchState: ~Copyable"))
        #expect(output.contains("public var folderWatch: FolderWatchClient"))
    }

    @Test("Emitter namespaces states to avoid machine collisions")
    func namespacesStatesAcrossMachines() {
        let lhs = SwiftCodeEmitter().emit(ast: makeFolderWatchAST(machineName: "FolderWatch"))
        let rhs = SwiftCodeEmitter().emit(ast: makeFolderWatchAST(machineName: "Bluetooth"))
        let combined = lhs + "\n\n" + rhs

        #expect(combined.contains("public enum FolderWatchMachine {"))
        #expect(combined.contains("public enum BluetoothMachine {"))
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

        let output = SwiftCodeEmitter().emit(ast: ast)
        #expect(output.contains("public enum NoContextMachine {"))
        #expect(output.contains("public struct RuntimeContext: Sendable {"))
        #expect(output.contains("struct NoContextRuntimeContext: Sendable"))
        #expect(output.contains("private var internalContext: NoContextMachine.RuntimeContext"))
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

        let generated = SwiftCodeEmitter().emit(ast: ast)

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

        try (generated + "\n\nprint(\"ok\")\n").write(
            to: sourcesDir.appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )

        let result = try runProcess("/usr/bin/env", ["swift", "build"], cwd: packageDir)
        #expect(result.0 == 0)
    }
}

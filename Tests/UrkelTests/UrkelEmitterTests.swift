import Foundation
import Testing
@testable import Urkel

@Suite("US 4.1 + 4.2 + 4.3 - Emitter")
struct UrkelEmitterTests {
    @Test("Emitter includes imports, states, observer and client")
    func emitsCoreSections() {
        let ast = makeFolderWatchAST()
        let output = UrkelEmitter().emit(ast: ast)

        #expect(output.contains("import Foundation"))
        #expect(output.contains("public enum Idle {}"))
        #expect(output.contains("public struct FolderWatchObserver<State>: ~Copyable"))
        #expect(output.contains("public struct FolderWatchClient: Sendable"))
        #expect(output.contains("extension DependencyValues"))
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

        let output = UrkelEmitter().emit(ast: ast)
        #expect(output.contains("extension BluetoothObserver where State == Idle"))
        #expect(output.contains("public consuming func start() async throws -> BluetoothObserver<Scanning>"))
        #expect(output.contains("public consuming func fail() async throws -> BluetoothObserver<Error>"))
        #expect(output.contains("public consuming func found(device: Peripheral) async throws -> BluetoothObserver<Idle>"))
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

        let generated = UrkelEmitter().emit(ast: ast)

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

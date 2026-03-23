import Foundation
import Testing
@testable import Urkel

@Suite("US 5.1 + 5.2 - Watch + Plugin")
struct WatchAndPluginTests {
    @Test("Watch service performs initial generation")
    func watchInitialGeneration() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let input = root.appendingPathComponent("in")
        let output = root.appendingPathComponent("out")
        try fm.createDirectory(at: input, withIntermediateDirectories: true)

        let machine = input.appendingPathComponent("FolderWatch.urkel")
        try """
        machine FolderWatch
        @factory makeObserver()
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(to: machine, atomically: true, encoding: .utf8)

        try await UrkelWatchService().run(
            inputDirectory: input.path,
            outputDirectory: output.path,
            pollIntervalNanoseconds: 50_000_000,
            stopAfterInitial: true
        )

        #expect(fm.fileExists(atPath: output.appendingPathComponent("FolderWatchStateMachine.swift").path))
    }

    @Test("Watch service removes generated file when source is deleted")
    func watchDeletesGeneratedOnSourceDeletion() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let input = root.appendingPathComponent("in")
        let output = root.appendingPathComponent("out")
        try fm.createDirectory(at: input, withIntermediateDirectories: true)

        let machine = input.appendingPathComponent("FolderWatch.urkel")
        try """
        machine FolderWatch
        @factory makeObserver()
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(to: machine, atomically: true, encoding: .utf8)

        let watcher = Task {
            try await UrkelWatchService().run(
                inputDirectory: input.path,
                outputDirectory: output.path,
                pollIntervalNanoseconds: 50_000_000
            )
        }
        defer { watcher.cancel() }

        let generated = output.appendingPathComponent("FolderWatchStateMachine.swift")

        let createDeadline = Date().addingTimeInterval(2)
        while !fm.fileExists(atPath: generated.path), Date() < createDeadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(fm.fileExists(atPath: generated.path))

        try fm.removeItem(at: machine)

        let deleteDeadline = Date().addingTimeInterval(2)
        while fm.fileExists(atPath: generated.path), Date() < deleteDeadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(!fm.fileExists(atPath: generated.path))
    }

    @Test("Watch service applies config imports and output directory")
    func watchConfigParity() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let input = root.appendingPathComponent("in")
        let output = root.appendingPathComponent("out")
        try fm.createDirectory(at: input, withIntermediateDirectories: true)

        let machine = input.appendingPathComponent("FolderWatch.urkel")
        let config = input.appendingPathComponent("urkel-config.json")
        try """
        machine FolderWatch
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(to: machine, atomically: true, encoding: .utf8)

        try """
        {
          "outputDirectory": "nested",
          "imports": {
            "swift": ["Foundation", "CustomWatchSDK"]
          }
        }
        """.write(to: config, atomically: true, encoding: .utf8)

        try await UrkelWatchService().run(
            inputDirectory: input.path,
            outputDirectory: output.path,
            stopAfterInitial: true
        )

        let generated = output.appendingPathComponent("nested/FolderWatchStateMachine.swift")
        #expect(fm.fileExists(atPath: generated.path))
        let body = try String(contentsOf: generated, encoding: .utf8)
        #expect(body.contains("import CustomWatchSDK"))
    }

    @Test("Plugin fixture builds and triggers generation")
    func pluginFixtureBuilds() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/PluginFixture")
        let buildDirectory = fixture.appendingPathComponent(".build")
        try? FileManager.default.removeItem(at: buildDirectory)

        let result = try runProcess("/usr/bin/env", ["swift", "build", "--quiet"], cwd: fixture)
        #expect(result.0 == 0)

        let enumerator = FileManager.default.enumerator(at: buildDirectory, includingPropertiesForKeys: nil)
        var foundGeneratedKotlinFile = false

        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == "Test.kt" {
                foundGeneratedKotlinFile = true
                let body = try String(contentsOf: url, encoding: .utf8)
                #expect(body.contains("import kotlin.collections"))
                #expect(body.contains("import kotlin.io"))
                break
            }
        }

        #expect(foundGeneratedKotlinFile)
    }

    @Test("Plugin fixture reports actionable error for legacy config import keys")
    func pluginFixtureLegacyConfigKeyFailsCleanly() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixture = root.appendingPathComponent("PluginLegacyFixture")
        let sourceDirectory = fixture.appendingPathComponent("Sources/Fixture")
        try fm.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "PluginLegacyFixture",
            platforms: [.macOS(.v13)],
            dependencies: [
                .package(path: "\(packageRoot.path)")
            ],
            targets: [
                .executableTarget(
                    name: "Fixture",
                    plugins: [
                        .plugin(name: "UrkelPlugin", package: "Urkel")
                    ]
                )
            ]
        )
        """.write(
            to: fixture.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        try """
        machine Test
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(
            to: sourceDirectory.appendingPathComponent("Test.urkel"),
            atomically: true,
            encoding: .utf8
        )

        try "print(\"fixture\")\n".write(
            to: sourceDirectory.appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )

        let config = fixture.appendingPathComponent("Sources/Fixture/urkel-config.json")
        try """
        {
          "swiftImports": ["Foundation"]
        }
        """.write(to: config, atomically: true, encoding: .utf8)

        let result = try runProcess("/usr/bin/env", ["swift", "build", "--quiet"], cwd: fixture)
        #expect(result.0 != 0)
        let combinedOutput = result.1 + "\n" + result.2
        #expect(combinedOutput.contains("swiftImports"))
        #expect(combinedOutput.contains("Legacy config key"))
        #expect(combinedOutput.contains("\"imports\""))
    }
}

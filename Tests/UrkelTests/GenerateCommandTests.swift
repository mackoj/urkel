import Foundation
import Testing
@testable import Urkel
@testable import UrkelCLI

@Suite("Generate command behavior")
struct GenerateCommandTests {
    @Test("Generate accepts directory input and produces outputs for all .urkel files")
    func generateDirectoryInput() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputDir = root.appendingPathComponent("Examples")
        let outputDir = root.appendingPathComponent("Generated")

        try fm.createDirectory(at: inputDir, withIntermediateDirectories: true)

        let a = inputDir.appendingPathComponent("Bluetooth.urkel")
        let b = inputDir.appendingPathComponent("FolderWatch.urkel")

        try """
        machine Bluetooth
        @states
          init Disconnected
          state Connected
        @transitions
          Disconnected -> connect -> Connected
        """.write(to: a, atomically: true, encoding: .utf8)

        try """
        machine FolderWatch
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(to: b, atomically: true, encoding: .utf8)

        let parsed = try UrkelCLI.parseAsRoot([
            "generate",
            inputDir.path,
            "--output",
            outputDir.path
        ])
        guard var command = parsed as? UrkelCLI.Generate else {
            Issue.record("Expected generate command")
            return
        }
        try await command.run()

        #expect(fm.fileExists(atPath: outputDir.appendingPathComponent("BluetoothMachine.swift").path))
        #expect(fm.fileExists(atPath: outputDir.appendingPathComponent("FolderWatchMachine.swift").path))
    }

    @Test("Generate uses config imports map and output directory")
    func generateUsesConfigImportsAndDirectory() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputDir = root.appendingPathComponent("Machines")
        let outputDir = root.appendingPathComponent("Generated")
        try fm.createDirectory(at: inputDir, withIntermediateDirectories: true)

        let machine = inputDir.appendingPathComponent("ConfigDriven.urkel")
        let config = inputDir.appendingPathComponent("urkel-config.json")

        try """
        machine ConfigDriven
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
            "swift": ["Foundation", "MySDK"]
          }
        }
        """.write(to: config, atomically: true, encoding: .utf8)

        let parsed = try UrkelCLI.parseAsRoot([
            "generate",
            machine.path,
            "--output",
            outputDir.path
        ])
        guard var command = parsed as? UrkelCLI.Generate else {
            Issue.record("Expected generate command")
            return
        }
        try await command.run()

        let generated = outputDir.appendingPathComponent("nested/ConfigDrivenMachine.swift")
        #expect(fm.fileExists(atPath: generated.path))
        let body = try String(contentsOf: generated, encoding: .utf8)
        #expect(body.contains("import MySDK"))
    }

    @Test("Generate rejects legacy config import keys with actionable error")
    func generateRejectsLegacyConfigImportKeys() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputDir = root.appendingPathComponent("Machines")
        let outputDir = root.appendingPathComponent("Generated")
        try fm.createDirectory(at: inputDir, withIntermediateDirectories: true)

        let machine = inputDir.appendingPathComponent("LegacyConfig.urkel")
        let config = inputDir.appendingPathComponent("urkel-config.json")

        try """
        machine LegacyConfig
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(to: machine, atomically: true, encoding: .utf8)

        try """
        {
          "swiftImports": ["Foundation"]
        }
        """.write(to: config, atomically: true, encoding: .utf8)

        let parsed = try UrkelCLI.parseAsRoot([
            "generate",
            machine.path,
            "--output",
            outputDir.path
        ])
        guard var command = parsed as? UrkelCLI.Generate else {
            Issue.record("Expected generate command")
            return
        }

        do {
            try await command.run()
            Issue.record("Expected legacy config validation error")
        } catch let error as UrkelGeneratorError {
            #expect(error.localizedDescription.contains("swiftImports"))
            #expect(error.localizedDescription.contains("\"imports\""))
        }
    }
}

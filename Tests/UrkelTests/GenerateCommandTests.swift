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

        #expect(fm.fileExists(atPath: outputDir.appendingPathComponent("Bluetooth+Generated.swift").path))
        #expect(fm.fileExists(atPath: outputDir.appendingPathComponent("FolderWatch+Generated.swift").path))
    }
}

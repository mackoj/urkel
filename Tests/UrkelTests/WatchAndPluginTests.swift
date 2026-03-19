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

        #expect(fm.fileExists(atPath: output.appendingPathComponent("FolderWatch+Generated.swift").path))
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

        let generated = output.appendingPathComponent("FolderWatch+Generated.swift")

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

    @Test("Plugin fixture builds and triggers generation")
    func pluginFixtureBuilds() throws {
        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/PluginFixture")

        let result = try runProcess("/usr/bin/env", ["swift", "build"], cwd: fixture)
        #expect(result.0 == 0)
    }
}

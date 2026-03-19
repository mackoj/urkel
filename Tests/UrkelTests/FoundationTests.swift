import ArgumentParser
import Foundation
import Testing
@testable import Urkel
@testable import UrkelCLI

@Suite("US 1.1 - CLI Foundation")
struct CLIFoundationTests {
    @Test("CLI shows generate and watch in help")
    func helpContainsCommands() throws {
        let helpText = UrkelCLI.helpMessage()
        #expect(helpText.contains("generate"))
        #expect(helpText.contains("watch"))
    }

    @Test("Generate command captures input and output")
    func generateCapturesArguments() throws {
        let command = try UrkelCLI.parseAsRoot(["generate", "./Bluetooth.urkel", "--output", "./Generated"]) as! UrkelCLI.Generate
        #expect(command.input == "./Bluetooth.urkel")
        #expect(command.output == "./Generated")
    }

    @Test("Watch command captures input and output")
    func watchCapturesArguments() throws {
        let command = try UrkelCLI.parseAsRoot(["watch", "./Sources", "--output", "./Generated"]) as! UrkelCLI.Watch
        #expect(command.input == "./Sources")
        #expect(command.output == "./Generated")
    }
}

@Suite("US 1.2 - File Pipeline")
struct FilePipelineTests {
    @Test("Generate writes placeholder output")
    func writesPlaceholderFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputDir = root.appendingPathComponent("in")
        let outputDir = root.appendingPathComponent("out")
        try fm.createDirectory(at: inputDir, withIntermediateDirectories: true)
        let input = inputDir.appendingPathComponent("Test.urkel")
        try "machine Test\n@states\n  init Idle\n@transitions\n  Idle -> start -> Idle\n".write(to: input, atomically: true, encoding: .utf8)

        let generated = try UrkelGenerator().generatePlaceholder(inputPath: input.path, outputPath: outputDir.path)
        #expect(fm.fileExists(atPath: generated.path))

        let contents = try String(contentsOf: generated, encoding: .utf8)
        #expect(contents.contains("Placeholder"))
    }

    @Test("Generate fails when input file is missing")
    func missingFileFails() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            _ = try UrkelGenerator().generatePlaceholder(
                inputPath: root.appendingPathComponent("missing.urkel").path,
                outputPath: root.appendingPathComponent("out").path
            )
            Issue.record("Expected file not found error")
        } catch let error as UrkelGeneratorError {
            #expect(error.localizedDescription.contains("File not found"))
        }
    }
}

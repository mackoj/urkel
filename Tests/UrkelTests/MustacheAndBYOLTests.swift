import Foundation
import Testing
@testable import Urkel

@Suite("US 7.1 + 7.2 + 7.3 - Template emitter + BYOL")
struct TemplateEmitterAndBYOLTests {
    @Test("Template emitter renders machine name")
    func mustacheRender() throws {
        let output = try TemplateCodeEmitter().render(
            ast: makeFolderWatchAST(),
            templateString: "Hello {{machineName}}"
        )
        #expect(output == "Hello FolderWatch")
    }

    @Test("Generator uses custom template with ext")
    func customTemplateGeneration() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appendingPathComponent("Bluetooth.urkel")
        let outputDir = root.appendingPathComponent("out")
        let template = root.appendingPathComponent("custom.ts.mustache")

        try """
        machine Bluetooth
        @states
          init Disconnected
          state Connected
        @transitions
          Disconnected -> connect -> Connected
        """.write(to: input, atomically: true, encoding: .utf8)

        try "export const machine = '{{machineName}}';".write(to: template, atomically: true, encoding: .utf8)

        let generated = try UrkelGenerator().generate(
            inputPath: input.path,
            outputPath: outputDir.path,
            templatePath: template.path,
            outputExtension: "ts"
        )

        #expect(generated.lastPathComponent == "Bluetooth.ts")
        let body = try String(contentsOf: generated, encoding: .utf8)
        #expect(body.contains("Bluetooth"))
    }

    @Test("Generator uses bundled Kotlin template via --lang")
    func bundledKotlinTemplate() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appendingPathComponent("Machine.urkel")
        let outputDir = root.appendingPathComponent("out")

        try """
        machine Sample
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(to: input, atomically: true, encoding: .utf8)

        let generated = try UrkelGenerator().generate(
            inputPath: input.path,
            outputPath: outputDir.path,
            language: "kotlin"
        )

        #expect(generated.lastPathComponent == "Machine.kt")
        let body = try String(contentsOf: generated, encoding: .utf8)
        #expect(body.contains("sealed interface SampleState"))
        #expect(body.contains("data object Idle"))
        #expect(body.contains("SampleTransitions"))
    }
}

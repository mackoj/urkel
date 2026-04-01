import Foundation
import Testing
@testable import Urkel

@Suite("US 7.1 + 7.2 + 7.3 - Template emitter + BYOL")
struct TemplateEmitterAndBYOLTests {

    @Test("MustacheEmitter renders machine name")
    func mustacheRender() throws {
        let file = makeFolderWatchFile()
        let output = try MustacheEmitter().render(file: file, templateString: "Hello {{machineName}}")
        #expect(output == "Hello FolderWatch")
    }

    @Test("MustacheEmitter import overrides are passed to context")
    func templateImportOverride() throws {
        let fileWithImports = UrkelFile(
            machineName: "FolderWatch",
            imports: [
                ImportDecl(name: "kotlin.collections"),
                ImportDecl(name: "kotlinx.coroutines"),
            ],
            states: makeFolderWatchFile().states,
            transitions: makeFolderWatchFile().transitions
        )
        // imports in templateContext is [String] (array of names), use {{.}} for current element
        let output = try MustacheEmitter().render(
            file: fileWithImports,
            templateString: "{{#imports}}{{.}} {{/imports}}"
        )
        #expect(output.contains("kotlin.collections"))
        #expect(output.contains("kotlinx.coroutines"))
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
          final Stopped
        @transitions
          Disconnected -> connect -> Connected
          Connected -> stop -> Stopped
        """.write(to: input, atomically: true, encoding: .utf8)

        try "export const machine = '{{machineName}}';".write(to: template, atomically: true, encoding: .utf8)

        let generated = try UrkelGenerator().generate(
            inputPath: input.path,
            outputPath: outputDir.path,
            templatePath: template.path,
            outputExtension: "ts"
        )

        #expect(generated.first?.lastPathComponent == "Bluetooth.ts")
        let body = try String(contentsOf: generated[0], encoding: .utf8)
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
          final Done
        @transitions
          Idle -> start -> Running
          Running -> finish -> Done
        """.write(to: input, atomically: true, encoding: .utf8)

        let generated = try UrkelGenerator().generate(
            inputPath: input.path,
            outputPath: outputDir.path,
            language: "kotlin"
        )

        #expect(generated.first?.pathExtension == "kt")
        let body = try String(contentsOf: generated[0], encoding: .utf8)
        #expect(!body.isEmpty)
    }
}

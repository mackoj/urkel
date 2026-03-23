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

    @Test("Template emitter import overrides are passed to context")
    func templateImportOverride() throws {
        let output = try TemplateCodeEmitter().render(
            ast: makeFolderWatchAST(),
            templateString: "{{#imports}}{{.}} {{/imports}}",
            templateImportsOverride: ["kotlin.collections", "kotlinx.coroutines"]
        )
        #expect(output.contains("kotlin.collections"))
        #expect(output.contains("kotlinx.coroutines"))
        #expect(!output.contains("Foundation"))
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
        @transitions
          Idle -> start -> Running
        """.write(to: input, atomically: true, encoding: .utf8)

        let generated = try UrkelGenerator().generate(
            inputPath: input.path,
            outputPath: outputDir.path,
            language: "kotlin"
        )

        #expect(generated.first?.lastPathComponent == "Machine.kt")
        let body = try String(contentsOf: generated[0], encoding: .utf8)
        #expect(body.contains("sealed interface SampleState"))
        #expect(body.contains("data object Idle"))
        #expect(body.contains("val sampleTransitions"))
    }

    @Test("Generator supports emitter-specific import overrides")
    func generatorImportOverrides() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appendingPathComponent("Machine.urkel")
        let outputDir = root.appendingPathComponent("out")
        let template = root.appendingPathComponent("custom.kt.mustache")

        try """
        machine Sample
        @states
          init Idle
          state Running
        @transitions
          Idle -> start -> Running
        """.write(to: input, atomically: true, encoding: .utf8)

        try "{{#imports}}import {{.}}\n{{/imports}}machine {{machineName}}".write(
            to: template,
            atomically: true,
            encoding: .utf8
        )

        let swiftGenerated = try UrkelGenerator().generate(
            inputPath: input.path,
            outputPath: outputDir.path,
            swiftImports: ["Foundation", "MySDK"]
        )
        let swiftBody = try String(contentsOf: swiftGenerated[0], encoding: .utf8)
        #expect(swiftBody.contains("import MySDK"))

        let templateGenerated = try UrkelGenerator().generate(
            inputPath: input.path,
            outputPath: outputDir.path,
            templatePath: template.path,
            outputExtension: "kt",
            templateImports: ["kotlin.collections", "kotlin.io"]
        )
        let templateBody = try String(contentsOf: templateGenerated[0], encoding: .utf8)
        #expect(templateBody.contains("import kotlin.collections"))
        #expect(templateBody.contains("import kotlin.io"))
    }

    @Test("Template context includes grouped transitions and naming metadata")
    func templateContextExpansion() {
        let ast = makeFolderWatchAST(machineName: "folder_watch")
        let context = ast.templateContext

        let machineTypeName = context["machineTypeName"] as? String
        #expect(machineTypeName == "FolderWatch")

        let groupedTransitions = context["groupedTransitions"] as? [[String: Any]]
        #expect(groupedTransitions?.isEmpty == false)

        let states = context["states"] as? [[String: Any]]
        #expect(states?.contains(where: { ($0["typeName"] as? String) == "Idle" }) == true)
    }
}

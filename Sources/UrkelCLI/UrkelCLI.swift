import ArgumentParser
import Foundation
import Urkel

@main
struct UrkelCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "urkel",
        abstract: "Generate compile-time safe typestate Swift from .urkel DSL files.",
        subcommands: [Generate.self, Watch.self]
    )

    struct Generate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate files from a .urkel source.")

        @Argument(help: "Path to the input .urkel file")
        var input: String

        @Option(name: .shortAndLong, help: "Output directory")
        var output: String

        @Option(name: .shortAndLong, help: "Path to a custom .mustache template for foreign language generation")
        var template: String?

        @Option(name: .shortAndLong, help: "Output extension for custom template or language mode (e.g. ts, kt, py)")
        var ext: String?

        @Option(name: .shortAndLong, help: "Use a bundled language template (currently: kotlin)")
        var lang: String?

        @Option(name: .customLong("swift-import"), help: "Override Swift emitter imports (repeat option or use comma-separated values)")
        var swiftImports: [String] = []

        @Option(name: .customLong("template-import"), help: "Override template/language emitter imports (repeat option or use comma-separated values)")
        var templateImports: [String] = []

        @Flag(name: .customLong("print-effective-config"), help: "Print effective Urkel config for each generated file")
        var printEffectiveConfig = false

        mutating func run() async throws {
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: input, isDirectory: &isDirectory) else {
                throw UrkelGeneratorError.fileNotFound(URL(fileURLWithPath: input).path)
            }

            let generator = UrkelGenerator()
            let normalizedSwiftImports = normalizedImportList(swiftImports)
            let normalizedTemplateImports = normalizedImportList(templateImports)
            let swiftImportsOption = normalizedSwiftImports.isEmpty ? nil : normalizedSwiftImports
            let templateImportsOption = normalizedTemplateImports.isEmpty ? nil : normalizedTemplateImports
            let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

            if isDirectory.boolValue {
                let generated = try generator.generateDirectory(
                    inputDirectoryPath: input,
                    outputPath: output,
                    templatePath: template,
                    outputExtension: ext,
                    language: lang,
                    swiftImports: swiftImportsOption,
                    templateImports: templateImportsOption,
                    additionalConfigSearchDirectories: [cwdURL],
                    verboseConfiguration: printEffectiveConfig
                )
                for file in generated {
                    print("Generated: \(file.path)")
                }
            } else {
                let generated = try generator.generate(
                    inputPath: input,
                    outputPath: output,
                    templatePath: template,
                    outputExtension: ext,
                    language: lang,
                    swiftImports: swiftImportsOption,
                    templateImports: templateImportsOption,
                    additionalConfigSearchDirectories: [cwdURL],
                    verboseConfiguration: printEffectiveConfig
                )
                for file in generated {
                    print("Generated: \(file.path)")
                }
            }
        }
    }

    struct Watch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Watch a directory for .urkel changes.")

        @Argument(help: "Path to directory to watch")
        var input: String

        @Option(name: .shortAndLong, help: "Output directory")
        var output: String

        @Option(name: .shortAndLong, help: "Path to a custom .mustache template for foreign language generation")
        var template: String?

        @Option(name: .shortAndLong, help: "Output extension for custom template or language mode (e.g. ts, kt, py)")
        var ext: String?

        @Option(name: .shortAndLong, help: "Use a bundled language template (currently: kotlin)")
        var lang: String?

        @Option(name: .customLong("swift-import"), help: "Override Swift emitter imports (repeat option or use comma-separated values)")
        var swiftImports: [String] = []

        @Option(name: .customLong("template-import"), help: "Override template/language emitter imports (repeat option or use comma-separated values)")
        var templateImports: [String] = []

        @Flag(name: .customLong("print-effective-config"), help: "Print effective Urkel config for each generated file")
        var printEffectiveConfig = false

        mutating func run() async throws {
            let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            try await UrkelWatchService().run(
                inputDirectory: input,
                outputDirectory: output,
                templatePath: template,
                outputExtension: ext,
                language: lang,
                swiftImports: normalizedImportList(swiftImports),
                templateImports: normalizedImportList(templateImports),
                additionalConfigSearchDirectories: [cwdURL],
                verboseConfiguration: printEffectiveConfig
            )
        }
    }
}

private func normalizedImportList(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []

    for raw in values {
        for segment in raw.split(separator: ",") {
            let value = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
    }

    return result
}

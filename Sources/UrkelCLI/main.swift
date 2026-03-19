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

        @Option(name: .customLong("output-file"), help: "Output file path relative to the output directory")
        var outputFile: String?

        @Option(name: .shortAndLong, help: "Path to a custom .mustache template for foreign language generation")
        var template: String?

        @Option(name: .shortAndLong, help: "Output extension for custom template or language mode (e.g. ts, kt, py)")
        var ext: String?

        @Option(name: .shortAndLong, help: "Use a bundled language template (currently: kotlin)")
        var lang: String?

        mutating func run() async throws {
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: input, isDirectory: &isDirectory) else {
                throw UrkelGeneratorError.fileNotFound(URL(fileURLWithPath: input).path)
            }

            let generator = UrkelGenerator()
            if isDirectory.boolValue {
                if let outputFile {
                    throw ValidationError("The output file option only works when generating a single .urkel file.")
                }

                let generated = try generator.generateDirectory(
                    inputDirectoryPath: input,
                    outputPath: output,
                    templatePath: template,
                    outputExtension: ext,
                    language: lang
                )
                for file in generated {
                    print("Generated: \(file.path)")
                }
            } else {
                let generated = try generator.generate(
                    inputPath: input,
                    outputPath: output,
                    outputFilePath: outputFile,
                    templatePath: template,
                    outputExtension: ext,
                    language: lang
                )
                print("Generated: \(generated.path)")
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

        mutating func run() async throws {
            try await UrkelWatchService().run(
                inputDirectory: input,
                outputDirectory: output,
                templatePath: template,
                outputExtension: ext,
                language: lang
            )
        }
    }
}

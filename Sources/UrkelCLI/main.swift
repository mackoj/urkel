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

        mutating func run() async throws {
            let generated = try UrkelGenerator().generate(
                inputPath: input,
                outputPath: output,
                templatePath: template,
                outputExtension: ext,
                language: lang
            )
            print("Generated: \(generated.path)")
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

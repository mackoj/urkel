import ArgumentParser
import Foundation
import Urkel
import UrkelVisualize

@main
struct UrkelCLI: AsyncParsableCommand {
    nonisolated(unsafe) static var configuration = CommandConfiguration(
        commandName: "urkel",
        abstract: "Urkel — type-safe state machine code generator",
        subcommands: [Generate.self, Watch.self, Validate.self, Paths.self, TestStubs.self]
    )
}

extension UrkelCLI {
    struct Generate: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(
            abstract: "Generate Swift code from .urkel files"
        )

        @Argument(help: "Input .urkel file or directory")
        var input: String

        @Option(name: .shortAndLong, help: "Output directory")
        var output: String

        @Option(name: .long, help: "Template file path")
        var template: String? = nil

        @Option(name: .long, help: "Output file extension")
        var ext: String? = nil

        @Option(name: .long, help: "Target language")
        var lang: String? = nil

        @Option(name: .long, parsing: .upToNextOption, help: "Swift import statement(s)")
        var swiftImport: [String] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Template import(s)")
        var templateImport: [String] = []

        @Flag(name: .long, help: "Print effective configuration and exit")
        var printEffectiveConfig: Bool = false

        mutating func run() async throws {
            let swiftImports = normalizeImports(swiftImport)
            let templateImports = normalizeImports(templateImport)
            let generator = UrkelGenerator()

            var isDir = ObjCBool(false)
            if FileManager.default.fileExists(atPath: input, isDirectory: &isDir), isDir.boolValue {
                _ = try generator.generateDirectory(
                    inputDirectoryPath: input,
                    outputPath: output,
                    templatePath: template,
                    outputExtension: ext,
                    language: lang,
                    swiftImports: swiftImports.isEmpty ? nil : swiftImports,
                    templateImports: templateImports.isEmpty ? nil : templateImports,
                    verboseConfiguration: printEffectiveConfig
                )
            } else {
                _ = try generator.generate(
                    inputPath: input,
                    outputPath: output,
                    templatePath: template,
                    outputExtension: ext,
                    language: lang,
                    swiftImports: swiftImports.isEmpty ? nil : swiftImports,
                    templateImports: templateImports.isEmpty ? nil : templateImports,
                    verboseConfiguration: printEffectiveConfig
                )
            }
        }
    }

    struct Watch: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(
            abstract: "Watch a directory for .urkel changes and regenerate"
        )

        @Argument(help: "Input directory to watch")
        var input: String

        @Option(name: .shortAndLong, help: "Output directory")
        var output: String

        @Option(name: .long, help: "Template file path")
        var template: String? = nil

        @Option(name: .long, help: "Output file extension")
        var ext: String? = nil

        @Option(name: .long, help: "Target language")
        var lang: String? = nil

        @Option(name: .long, parsing: .upToNextOption, help: "Swift import statement(s)")
        var swiftImport: [String] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Template import(s)")
        var templateImport: [String] = []

        @Flag(name: .long, help: "Print effective configuration and exit")
        var printEffectiveConfig: Bool = false

        mutating func run() async throws {
            let swiftImports = normalizeImports(swiftImport)
            let templateImports = normalizeImports(templateImport)
            try await UrkelWatchService().run(
                inputDirectory: input,
                outputDirectory: output,
                templatePath: template,
                outputExtension: ext,
                language: lang,
                swiftImports: swiftImports,
                templateImports: templateImports,
                verboseConfiguration: printEffectiveConfig
            )
        }
    }

    struct Validate: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(
            abstract: "Validate a .urkel file and report diagnostics"
        )

        @Argument(help: "Input .urkel file")
        var input: String

        @Flag(name: .long, help: "Output diagnostics as JSON")
        var json: Bool = false

        mutating func run() async throws {
            let url = URL(fileURLWithPath: input)
            let source = try String(contentsOf: url, encoding: .utf8)
            let fallback = url.deletingPathExtension().lastPathComponent
            let file = try UrkelParser().parse(source: source, machineNameFallback: fallback)
            let diagnostics = UrkelValidator.validate(file)

            if json {
                let items = diagnostics.map { d -> [String: String] in
                    ["severity": d.severity == .error ? "error" : "warning",
                     "code": d.code.rawValue,
                     "message": d.message]
                }
                let data = try JSONSerialization.data(withJSONObject: items, options: .prettyPrinted)
                print(String(data: data, encoding: .utf8) ?? "[]")
            } else {
                for d in diagnostics {
                    let sev = d.severity == .error ? "error" : "warning"
                    fputs("\(sev): \(d.message)\n", stderr)
                }
            }

            if diagnostics.contains(where: { $0.severity == .error }) {
                throw ExitCode.failure
            }
        }
    }

    struct Paths: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(
            abstract: "Enumerate all init→final paths in a state machine"
        )

        @Argument(help: "Input .urkel file")
        var input: String

        @Option(name: .long, help: "Maximum number of paths to enumerate")
        var maxPaths: Int = 100

        mutating func run() async throws {
            let url = URL(fileURLWithPath: input)
            let source = try String(contentsOf: url, encoding: .utf8)
            let fallback = url.deletingPathExtension().lastPathComponent
            let file = try UrkelParser().parse(source: source, machineNameFallback: fallback)

            let paths = PathExplorer().paths(in: file, maxPaths: maxPaths)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(paths)
            print(String(data: data, encoding: .utf8) ?? "[]")
        }
    }

    struct TestStubs: AsyncParsableCommand {
        nonisolated(unsafe) static var configuration = CommandConfiguration(
            abstract: "Generate Swift test stubs for all init→final paths"
        )

        @Argument(help: "Input .urkel file")
        var input: String

        @Option(name: .long, help: "Maximum number of paths to cover")
        var maxPaths: Int = 100

        mutating func run() async throws {
            let url = URL(fileURLWithPath: input)
            let source = try String(contentsOf: url, encoding: .utf8)
            let fallback = url.deletingPathExtension().lastPathComponent
            let file = try UrkelParser().parse(source: source, machineNameFallback: fallback)

            let machineTN = typeName(from: file.machineName)
            let paths = PathExplorer().paths(in: file, maxPaths: maxPaths)

            var lines = ["import Testing", "@testable import \(machineTN)", ""]
            lines.append("@Suite(\"\(machineTN) path coverage\")")
            lines.append("struct \(machineTN)PathTests {")

            for (i, path) in paths.enumerated() {
                let steps = path.steps.map { "\($0.from) -> \($0.event) -> \($0.to)" }.joined(separator: "; ")
                lines.append("    @Test(\"path \(i + 1): \(steps)\")")
                lines.append("    func path\(i + 1)() async throws {")
                lines.append("        // TODO: implement path test for [\(steps)]")
                lines.append("    }")
                lines.append("")
            }
            lines.append("}")
            print(lines.joined(separator: "\n"))
        }
    }
}

private func normalizeImports(_ raw: [String]) -> [String] {
    raw.flatMap { $0.components(separatedBy: ",") }
       .map { $0.trimmingCharacters(in: .whitespaces) }
       .filter { !$0.isEmpty }
}

import Foundation
import PackagePlugin

@main
struct UrkelGenerate: CommandPlugin {
    private static let configurationFileNames = [
        "urkel-config.json",
        ".urkel-config.json",
        ".urkel-config",
        ".urkelconfig.json",
        ".urkelconfig"
    ]
    private static let legacyImportKeys: Set<String> = ["swiftImports", "templateImports"]

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        _ = arguments

        let tool = try context.tool(named: "UrkelCLI")
        let packageDirectoryURL = context.package.directoryURL
        var generatedFiles: [URL] = []

        for case let sourceTarget as SourceModuleTarget in context.package.targets {
            for source in sourceTarget.sourceFiles {
                let sourceURL = source.url
                let configuration = try self.configuration(
                    for: sourceURL,
                    targetDirectoryURL: sourceTarget.directoryURL,
                    packageDirectoryURL: packageDirectoryURL
                )

                guard configuration.shouldGenerate(for: sourceURL) else {
                    continue
                }

                let outputDirectoryURL = configuration.outputDirectoryURL(
                    in: packageDirectoryURL
                )
                let generatedURL = configuration.generatedOutputURL(
                    for: sourceURL,
                    outputDirectoryURL: outputDirectoryURL
                )

                var processArguments = [
                    "generate",
                    sourceURL.path,
                    "--output",
                    outputDirectoryURL.path
                ]

                if let templatePath = configuration.resolvedTemplatePath {
                    processArguments += ["--template", templatePath]
                }

                if let outputExtension = configuration.outputExtension {
                    processArguments += ["--ext", outputExtension]
                }

                if let language = configuration.language {
                    processArguments += ["--lang", language]
                }

                if let outputFile = configuration.outputFile {
                    processArguments += ["--output-file", outputFile]
                }

                for item in configuration.swiftImports {
                    processArguments += ["--swift-import", item]
                }

                for item in configuration.templateImports {
                    processArguments += ["--template-import", item]
                }

                let process = Process()
                process.executableURL = tool.url
                process.arguments = processArguments
                try process.run()
                process.waitUntilExit()

                guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                    throw PluginError.failed(
                        sourcePath: sourceURL.path,
                        status: process.terminationStatus
                    )
                }

                generatedFiles.append(generatedURL)
            }
        }

        if generatedFiles.isEmpty {
            Diagnostics.remark("UrkelGenerate finished with no files to generate")
        } else {
            Diagnostics.remark("UrkelGenerate wrote \(generatedFiles.count) file(s)")
        }
    }

    private func configuration(
        for sourceURL: URL,
        targetDirectoryURL: URL,
        packageDirectoryURL: URL
    ) throws -> ResolvedConfiguration {
        let configurationURL = Self.configurationURL(for: sourceURL)
            ?? Self.configurationURL(in: targetDirectoryURL)
            ?? Self.configurationURL(in: packageDirectoryURL)
            ?? Self.configurationURL(in: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))

        guard let configurationURL else {
            return .default
        }

        do {
            let data = try Data(contentsOf: configurationURL)
            try Self.validateConfigurationData(data)
            let decoded = try JSONDecoder().decode(RawConfiguration.self, from: data)
            return ResolvedConfiguration(configurationURL: configurationURL, raw: decoded)
        } catch {
            let details = Self.humanReadableError(error)
            Diagnostics.error("Invalid Urkel command plugin configuration at \(configurationURL.path): \(details)")
            throw PluginError.invalidConfiguration(configurationURL, underlyingError: error)
        }
    }

    private static func configurationURL(in startDirectoryURL: URL) -> URL? {
        var directoryURL = startDirectoryURL
        let fileManager = FileManager.default

        while true {
            for fileName in configurationFileNames {
                let candidateURL = directoryURL.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
            }

            let parentURL = directoryURL.deletingLastPathComponent()
            if parentURL.path == directoryURL.path {
                return nil
            }

            directoryURL = parentURL
        }
    }

    private static func configurationURL(for sourceURL: URL) -> URL? {
        Self.configurationURL(in: sourceURL.deletingLastPathComponent())
    }

    private struct RawConfiguration: Decodable {
        var sourceExtensions: [String]? = nil
        var outputDirectory: String? = nil
        var outputFile: String? = nil
        var template: String? = nil
        var outputExtension: String? = nil
        var language: String? = nil
        var imports: [String: [String]]? = nil
    }

    private struct ResolvedConfiguration {
        static let `default` = ResolvedConfiguration(configurationURL: nil, raw: RawConfiguration())

        let configurationURL: URL?
        let raw: RawConfiguration

        var outputExtension: String? {
            raw.outputExtension
        }

        var language: String? {
            raw.language
        }

        var outputFile: String? {
            raw.outputFile
        }

        var swiftImports: [String] {
            let imports = normalized(raw.imports?["swift"])
            return imports
        }

        var templateImports: [String] {
            if let language = raw.language?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                let imports = normalized(raw.imports?[language])
                if !imports.isEmpty {
                    return imports
                }
            }
            let templateImports = normalized(raw.imports?["template"])
            return templateImports
        }

        var resolvedTemplatePath: String? {
            guard let template = raw.template else {
                return nil
            }

            guard let configurationDirectoryURL = configurationURL?.deletingLastPathComponent() else {
                return template
            }

            return URL(fileURLWithPath: template, relativeTo: configurationDirectoryURL).standardizedFileURL.path
        }

        func shouldGenerate(for sourceURL: URL) -> Bool {
            let sourceExtension = sourceURL.pathExtension.lowercased()
            let sourceExtensions = normalized(raw.sourceExtensions)

            guard !sourceExtensions.isEmpty else {
                return sourceExtension == "urkel"
            }

            return sourceExtensions.map { $0.lowercased() }.contains(sourceExtension)
        }

        func outputDirectoryURL(in packageDirectoryURL: URL) -> URL {
            guard let outputDirectory = raw.outputDirectory, !outputDirectory.isEmpty else {
                return packageDirectoryURL
            }

            return URL(
                fileURLWithPath: outputDirectory,
                relativeTo: packageDirectoryURL
            ).standardizedFileURL
        }

        func generatedOutputURL(for sourceURL: URL, outputDirectoryURL: URL) -> URL {
            if let outputFile = raw.outputFile, !outputFile.isEmpty {
                return URL(fileURLWithPath: outputFile, relativeTo: outputDirectoryURL).standardizedFileURL
            }

            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let outputExtension = resolvedOutputExtension(for: sourceURL)

            let outputName: String
            if raw.template != nil || raw.language != nil {
                outputName = "\(baseName).\(outputExtension)"
            } else {
                outputName = "\(baseName)+Generated.\(outputExtension)"
            }

            return outputDirectoryURL.appendingPathComponent(outputName)
        }

        private func resolvedOutputExtension(for sourceURL: URL) -> String {
            if let explicit = raw.outputExtension, !explicit.isEmpty {
                return explicit
            }

            if let template = raw.template {
                return Self.inferredExtension(fromTemplatePath: template)
            }

            if let language = raw.language {
                return Self.defaultExtension(forLanguage: language)
            }

            _ = sourceURL
            return "swift"
        }

        private static func inferredExtension(fromTemplatePath path: String) -> String {
            let templateName = URL(fileURLWithPath: path).lastPathComponent
            if templateName.hasSuffix(".mustache") {
                let withoutMustache = String(templateName.dropLast(".mustache".count))
                let ext = URL(fileURLWithPath: withoutMustache).pathExtension
                return ext.isEmpty ? "txt" : ext
            }

            let ext = URL(fileURLWithPath: templateName).pathExtension
            return ext.isEmpty ? "txt" : ext
        }

        private static func defaultExtension(forLanguage language: String) -> String {
            switch language.lowercased() {
                case "kotlin":
                    return "kt"
                default:
                    return "txt"
            }
        }

        private func normalized(_ values: [String]?) -> [String] {
            guard let values else { return [] }

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
    }

    private enum PluginError: LocalizedError {
        case invalidConfiguration(URL, underlyingError: Error)
        case failed(sourcePath: String, status: Int32)

        var errorDescription: String? {
            switch self {
                case .invalidConfiguration(let url, let underlyingError):
                    return "Invalid Urkel command plugin configuration at \(url.path): \(underlyingError.localizedDescription)"
                case .failed(let sourcePath, let status):
                    return "UrkelCLI failed while generating \(sourcePath) with exit status \(status)"
            }
        }
    }

    private static func humanReadableError(_ error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }
        return String(describing: error)
    }

    private static func validateConfigurationData(_ data: Data) throws {
        let rawObject = try JSONSerialization.jsonObject(with: data)
        guard let object = rawObject as? [String: Any] else {
            throw InvalidConfigurationShapeError()
        }

        let matchedLegacyKeys = legacyImportKeys
            .filter { object[$0] != nil }
            .sorted()
        guard !matchedLegacyKeys.isEmpty else {
            return
        }

        throw LegacyImportKeysError(keys: matchedLegacyKeys)
    }

    private struct LegacyImportKeysError: LocalizedError {
        let keys: [String]

        var errorDescription: String? {
            let joinedKeys = keys.map { "'\($0)'" }.joined(separator: ", ")
            return """
            Legacy config key(s) \(joinedKeys) are no longer supported. Use the "imports" map instead, for example: "imports": { "swift": ["Foundation"], "kotlin": ["kotlin.collections"] }.
            """
        }
    }

    private struct InvalidConfigurationShapeError: LocalizedError {
        var errorDescription: String? {
            "Configuration root must be a JSON object."
        }
    }
}

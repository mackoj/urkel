import Foundation

public enum UrkelConfigurationError: Error, LocalizedError {
    case invalidConfiguration(URL, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let url, let underlyingError):
            return "Invalid Urkel configuration at \(url.path): \(underlyingError.localizedDescription)"
        }
    }
}

public struct UrkelGenerationOverrides: Sendable {
    public var outputFilePath: String?
    public var templatePath: String?
    public var outputExtension: String?
    public var language: String?
    public var swiftImports: [String]?
    public var templateImports: [String]?

    public init(
        outputFilePath: String? = nil,
        templatePath: String? = nil,
        outputExtension: String? = nil,
        language: String? = nil,
        swiftImports: [String]? = nil,
        templateImports: [String]? = nil
    ) {
        self.outputFilePath = outputFilePath
        self.templatePath = templatePath
        self.outputExtension = outputExtension
        self.language = language
        self.swiftImports = swiftImports
        self.templateImports = templateImports
    }
}

public struct UrkelResolvedConfiguration: Equatable, Sendable {
    public let configurationURL: URL?
    public let outputDirectory: String?
    public let outputFilePath: String?
    public let templatePath: String?
    public let outputExtension: String?
    public let language: String?
    public let swiftImports: [String]?
    public let templateImports: [String]?
    public let sourceExtensions: [String]?
    public let importsByLanguage: [String: [String]]

    public init(
        configurationURL: URL?,
        outputDirectory: String?,
        outputFilePath: String?,
        templatePath: String?,
        outputExtension: String?,
        language: String?,
        swiftImports: [String]?,
        templateImports: [String]?,
        sourceExtensions: [String]?,
        importsByLanguage: [String: [String]]
    ) {
        self.configurationURL = configurationURL
        self.outputDirectory = outputDirectory
        self.outputFilePath = outputFilePath
        self.templatePath = templatePath
        self.outputExtension = outputExtension
        self.language = language
        self.swiftImports = swiftImports
        self.templateImports = templateImports
        self.sourceExtensions = sourceExtensions
        self.importsByLanguage = importsByLanguage
    }
}

public extension UrkelResolvedConfiguration {
    static let `default` = UrkelResolvedConfiguration(
        configurationURL: nil,
        outputDirectory: nil,
        outputFilePath: nil,
        templatePath: nil,
        outputExtension: nil,
        language: nil,
        swiftImports: nil,
        templateImports: nil,
        sourceExtensions: nil,
        importsByLanguage: [:]
    )
}

public enum UrkelConfigurationResolver {
    public static let configurationFileNames = [
        "urkel-config.json",
        ".urkel-config.json",
        ".urkel-config",
        ".urkelconfig.json",
        ".urkelconfig"
    ]

    public static func resolveGenerationConfiguration(
        for inputFileURL: URL,
        overrides: UrkelGenerationOverrides = UrkelGenerationOverrides(),
        additionalSearchDirectories: [URL] = [],
        fileManager: FileManager = .default
    ) throws -> UrkelResolvedConfiguration {
        let configurationURL = self.configurationURL(
            for: inputFileURL,
            additionalSearchDirectories: additionalSearchDirectories,
            fileManager: fileManager
        )

        let rawConfiguration: RawConfiguration
        if let configurationURL {
            do {
                let data = try Data(contentsOf: configurationURL)
                rawConfiguration = try JSONDecoder().decode(RawConfiguration.self, from: data)
            } catch {
                throw UrkelConfigurationError.invalidConfiguration(configurationURL, underlyingError: error)
            }
        } else {
            rawConfiguration = RawConfiguration()
        }

        let normalizedSourceExtensions = normalized(rawConfiguration.sourceExtensions)
        let importsByLanguage = normalizedImportsByLanguage(rawConfiguration.imports)

        let resolvedLanguage = overrides.language ?? rawConfiguration.language
        let resolvedTemplatePath = resolvedTemplatePath(
            overridePath: overrides.templatePath,
            configuredPath: rawConfiguration.template,
            configurationURL: configurationURL
        )

        let resolvedSwiftImports = overrideOrConfigured(
            override: normalized(overrides.swiftImports),
            configured: importsByLanguage["swift"] ?? normalized(rawConfiguration.swiftImports)
        )

        let templateLanguageKey = resolvedLanguage?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let templateImportsFromMap = templateLanguageKey.flatMap { importsByLanguage[$0] } ?? importsByLanguage["template"]
        let resolvedTemplateImports = overrideOrConfigured(
            override: normalized(overrides.templateImports),
            configured: templateImportsFromMap ?? normalized(rawConfiguration.templateImports)
        )

        return UrkelResolvedConfiguration(
            configurationURL: configurationURL,
            outputDirectory: rawConfiguration.outputDirectory,
            outputFilePath: overrides.outputFilePath ?? rawConfiguration.outputFile,
            templatePath: resolvedTemplatePath,
            outputExtension: overrides.outputExtension ?? rawConfiguration.outputExtension,
            language: resolvedLanguage,
            swiftImports: resolvedSwiftImports,
            templateImports: resolvedTemplateImports,
            sourceExtensions: normalizedSourceExtensions,
            importsByLanguage: importsByLanguage
        )
    }

    public static func configurationURL(
        for inputFileURL: URL,
        additionalSearchDirectories: [URL] = [],
        fileManager: FileManager = .default
    ) -> URL? {
        var visitedDirectories = Set<String>()
        let inputDirectoryURL = inputFileURL.deletingLastPathComponent().standardizedFileURL

        let orderedSearchRoots = [inputDirectoryURL] + additionalSearchDirectories.map(\.standardizedFileURL)
        for root in orderedSearchRoots {
            if let url = configurationURL(
                in: root,
                visitedDirectories: &visitedDirectories,
                fileManager: fileManager
            ) {
                return url
            }
        }

        return nil
    }

    public static func effectiveConfigurationSummary(
        inputFileURL: URL,
        resolved: UrkelResolvedConfiguration,
        outputDirectoryURL: URL
    ) -> String {
        let configLocation = resolved.configurationURL?.path ?? "<none>"
        let templateValue = resolved.templatePath ?? "<none>"
        let languageValue = resolved.language ?? "<none>"
        let extensionValue = resolved.outputExtension ?? "<default>"
        let outputFileValue = resolved.outputFilePath ?? "<default>"
        let swiftImports = resolved.swiftImports?.joined(separator: ", ") ?? "<default>"
        let templateImports = resolved.templateImports?.joined(separator: ", ") ?? "<default>"

        return """
        [urkel] effective config for \(inputFileURL.lastPathComponent):
          config: \(configLocation)
          outputDirectory: \(outputDirectoryURL.path)
          outputFile: \(outputFileValue)
          template: \(templateValue)
          language: \(languageValue)
          outputExtension: \(extensionValue)
          imports.swift: \(swiftImports)
          imports.template: \(templateImports)
        """
    }
}

private extension UrkelConfigurationResolver {
    struct RawConfiguration: Decodable {
        var sourceExtensions: [String]? = nil
        var outputDirectory: String? = nil
        var outputFile: String? = nil
        var template: String? = nil
        var outputExtension: String? = nil
        var language: String? = nil
        var imports: [String: [String]]? = nil
        var swiftImports: [String]? = nil
        var templateImports: [String]? = nil
    }

    static func configurationURL(
        in startDirectoryURL: URL,
        visitedDirectories: inout Set<String>,
        fileManager: FileManager
    ) -> URL? {
        var directoryURL = startDirectoryURL.standardizedFileURL

        while visitedDirectories.insert(directoryURL.path).inserted {
            for fileName in configurationFileNames {
                let candidateURL = directoryURL.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
            }

            let parentURL = directoryURL.deletingLastPathComponent()
            if parentURL.path == directoryURL.path {
                break
            }
            directoryURL = parentURL
        }

        return nil
    }

    static func normalizedImportsByLanguage(_ imports: [String: [String]]?) -> [String: [String]] {
        guard let imports else { return [:] }

        var normalizedMap: [String: [String]] = [:]
        for (language, values) in imports {
            let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalizedLanguage.isEmpty else { continue }
            guard let normalizedValues = normalized(values) else { continue }
            normalizedMap[normalizedLanguage] = normalizedValues
        }
        return normalizedMap
    }

    static func normalized(_ values: [String]?) -> [String]? {
        guard let values else { return nil }

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

        return result.isEmpty ? nil : result
    }

    static func overrideOrConfigured(override: [String]?, configured: [String]?) -> [String]? {
        override ?? configured
    }

    static func resolvedTemplatePath(
        overridePath: String?,
        configuredPath: String?,
        configurationURL: URL?
    ) -> String? {
        let templatePath = overridePath ?? configuredPath
        guard let templatePath else { return nil }

        guard let configurationDirectoryURL = configurationURL?.deletingLastPathComponent() else {
            return templatePath
        }

        return URL(fileURLWithPath: templatePath, relativeTo: configurationDirectoryURL).standardizedFileURL.path
    }
}

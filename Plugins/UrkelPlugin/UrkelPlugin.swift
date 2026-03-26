import Foundation
import PackagePlugin

@main
struct UrkelPlugin: BuildToolPlugin {
  private static let configurationFileNames = [
    "urkel-config.json",
    ".urkel-config.json",
    ".urkel-config",
    ".urkelconfig.json",
    ".urkelconfig"
  ]
  private static let legacyImportKeys: Set<String> = ["swiftImports", "templateImports"]

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let sourceTarget = target as? SourceModuleTarget else {
      return []
    }
    
    let tool = try context.tool(named: "UrkelCLI")
    let targetDirectoryURL = sourceTarget.directoryURL
    
        return try sourceTarget.sourceFiles.compactMap { source in
            let sourceURL = source.url
      let configuration = try self.configuration(
        for: sourceURL,
        targetDirectoryURL: targetDirectoryURL,
        context: context
      )
      
      guard configuration.shouldGenerate(for: sourceURL) else {
        return nil
      }
      
      let outputDirectoryURL = configuration.outputDirectoryURL(in: context)
      let generatedURLs = configuration.generatedOutputURLs(
        for: sourceURL,
        outputDirectoryURL: outputDirectoryURL
      )
      
      var arguments = [
        "generate",
        sourceURL.path,
        "--output",
        outputDirectoryURL.path
      ]
      
      if let templatePath = configuration.resolvedTemplatePath {
        arguments += ["--template", templatePath]
      }
      
      if let outputExtension = configuration.outputExtension {
        arguments += ["--ext", outputExtension]
      }
      
      if let language = configuration.language {
        arguments += ["--lang", language]
      }

      for item in configuration.swiftImports {
        arguments += ["--swift-import", item]
      }

      for item in configuration.templateImports {
        arguments += ["--template-import", item]
      }
      
      var inputFiles = [sourceURL]
      if let configurationURL = configuration.configurationURL {
        inputFiles.append(configurationURL)
      }
      
      return .buildCommand(
        displayName: "Generating \(generatedURLs[0].lastPathComponent)",
        executable: tool.url,
        arguments: arguments,
        inputFiles: inputFiles,
        outputFiles: generatedURLs
      )
    }
  }
  
  private func configuration(
    for sourceURL: URL,
    targetDirectoryURL: URL,
    context: PluginContext
  ) throws -> ResolvedConfiguration {
    let configurationURL = Self.configurationURL(for: sourceURL)
      ?? Self.configurationURL(in: targetDirectoryURL)
      ?? Self.configurationURL(in: context.package.directoryURL)
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
      Diagnostics.error("Invalid Urkel plugin configuration at \(configurationURL.path): \(details)")
      throw PluginConfigurationError.invalidConfiguration(configurationURL, underlyingError: error)
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
    var outputFolder: String? = nil
    /// Deprecated: use `outputFolder` instead.
    var outputDirectory: String? = nil
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
      nil
    }

    var swiftImports: [String] {
      let imports = normalized(raw.imports?["swift"])
      return imports
    }

    var templateImports: [String] {
      if let language = raw.language?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        let languageImports = normalized(raw.imports?[language])
        if !languageImports.isEmpty {
          return languageImports
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
    
    func outputDirectoryURL(in context: PluginContext) -> URL {
      context.pluginWorkDirectoryURL
    }
    
    func generatedOutputURLs(for sourceURL: URL, outputDirectoryURL: URL) -> [URL] {
      let resolvedOutputDirectoryURL = self.resolvedOutputDirectoryURL(from: outputDirectoryURL)

      let baseName = sourceURL.deletingPathExtension().lastPathComponent
      let outputExtension = resolvedOutputExtension(for: sourceURL)

      if raw.template != nil || raw.language != nil {
        let outputName = "\(baseName).\(outputExtension)"
        return [resolvedOutputDirectoryURL.appendingPathComponent(outputName)]
      }

      // For native Swift, register all 3 generated files so the build system
      // knows exactly which files each urkel source produces.
      let rawMachineName = Self.machineNameFromFile(at: sourceURL) ?? baseName
      let machineName = pascalCased(rawMachineName)
      return [
        resolvedOutputDirectoryURL.appendingPathComponent("\(machineName)Machine.swift"),
        resolvedOutputDirectoryURL.appendingPathComponent("\(machineName)Client.swift"),
        resolvedOutputDirectoryURL.appendingPathComponent("\(machineName)Client+Dependency.swift"),
      ]
    }

    /// Extracts the machine name from the first `machine <Name>` declaration in a `.urkel` file.
    private static func machineNameFromFile(at url: URL) -> String? {
      guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
      for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("machine ") else { continue }
        let name = String(trimmed.dropFirst("machine ".count))
          .trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
      }
      return nil
    }

    private func pascalCased(_ raw: String) -> String {
      let cleaned = raw
        .replacingOccurrences(of: "[^A-Za-z0-9]+", with: " ", options: .regularExpression)
        .split(separator: " ")
      guard !cleaned.isEmpty else { return raw }
      return cleaned.map { segment -> String in
        guard let first = segment.first else { return "" }
        return String(first).uppercased() + segment.dropFirst()
      }.joined()
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

    private func resolvedOutputDirectoryURL(from rootOutputURL: URL) -> URL {
      guard let outputFolder = raw.outputFolder ?? raw.outputDirectory, !outputFolder.isEmpty else {
        return rootOutputURL
      }

      return URL(fileURLWithPath: outputFolder, relativeTo: rootOutputURL).standardizedFileURL
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
  
  private enum PluginConfigurationError: LocalizedError {
    case invalidConfiguration(URL, underlyingError: Error)
    
    var errorDescription: String? {
      switch self {
        case .invalidConfiguration(let url, let underlyingError):
          return "Invalid Urkel plugin configuration at \(url.path): \(underlyingError.localizedDescription)"
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

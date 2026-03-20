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
      let generatedURL = configuration.generatedOutputURL(
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
      
      if let outputFile = configuration.outputFile {
        arguments += ["--output-file", outputFile]
      }
      
      var inputFiles = [sourceURL]
      if let configurationURL = configuration.configurationURL {
        inputFiles.append(configurationURL)
      }
      
      return .buildCommand(
        displayName: "Generating \(generatedURL.lastPathComponent)",
        executable: tool.url,
        arguments: arguments,
        inputFiles: inputFiles,
        outputFiles: [generatedURL]
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
      let decoded = try JSONDecoder().decode(RawConfiguration.self, from: data)
      return ResolvedConfiguration(configurationURL: configurationURL, raw: decoded)
    } catch {
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
    var outputDirectory: String? = nil
    var outputFile: String? = nil
    var template: String? = nil
    var outputExtension: String? = nil
    var language: String? = nil
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
      
      guard let sourceExtensions = raw.sourceExtensions, !sourceExtensions.isEmpty else {
        return sourceExtension == "urkel"
      }
      
      return sourceExtensions.map { $0.lowercased() }.contains(sourceExtension)
    }
    
    func outputDirectoryURL(in context: PluginContext) -> URL {
      guard let outputDirectory = raw.outputDirectory, !outputDirectory.isEmpty else {
        return context.pluginWorkDirectoryURL
      }
      
      return URL(
        fileURLWithPath: outputDirectory,
        relativeTo: context.pluginWorkDirectoryURL
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
}

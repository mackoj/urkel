import PackagePlugin

@main
struct UrkelPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        let tool = try context.tool(named: "UrkelCLI")

        return sourceTarget.sourceFiles
            .filter { $0.url.pathExtension == "urkel" }
            .map { source in
                let sourceURL = source.url
                let baseName = sourceURL.deletingPathExtension().lastPathComponent
                let output = context.pluginWorkDirectoryURL.appending(path: "\(baseName)+Generated.swift")
                return .buildCommand(
                    displayName: "Generating \(output.lastPathComponent)",
                    executable: tool.url,
                    arguments: [
                        "generate",
                        sourceURL.path,
                        "--output",
                        context.pluginWorkDirectoryURL.path
                    ],
                    inputFiles: [sourceURL],
                    outputFiles: [output]
                )
            }
    }
}

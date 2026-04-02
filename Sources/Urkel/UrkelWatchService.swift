import Foundation
import UrkelAST
import UrkelParser
import UrkelValidation
import UrkelEmitterSwift
import UrkelEmitterMustache

public struct UrkelWatchService {
    public init() {}

    public func run(
        inputDirectory: String,
        outputDirectory: String,
        templatePath: String? = nil,
        outputExtension: String? = nil,
        language: String? = nil,
        swiftImports: [String] = [],
        templateImports: [String] = [],
        additionalConfigSearchDirectories: [URL] = [],
        verboseConfiguration: Bool = false,
        pollIntervalNanoseconds: UInt64 = 300_000_000,
        stopAfterInitial: Bool = false
    ) async throws {
        let generator = UrkelGenerator()
        _ = try generator.generateDirectory(
            inputDirectoryPath: inputDirectory,
            outputPath: outputDirectory,
            templatePath: templatePath,
            outputExtension: outputExtension,
            language: language,
            swiftImports: swiftImports.isEmpty ? nil : swiftImports,
            templateImports: templateImports.isEmpty ? nil : templateImports,
            additionalConfigSearchDirectories: additionalConfigSearchDirectories,
            verboseConfiguration: verboseConfiguration
        )

        guard !stopAfterInitial else {
            return
        }

        var known = try snapshotForUrkelFiles(in: inputDirectory)
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            let current = try snapshotForUrkelFiles(in: inputDirectory)

            for (file, modifiedAt) in current {
                if known[file] != modifiedAt {
                    _ = try generator.generate(
                        inputPath: file,
                        outputPath: outputDirectory,
                        templatePath: templatePath,
                        outputExtension: outputExtension,
                        language: language,
                        swiftImports: swiftImports.isEmpty ? nil : swiftImports,
                        templateImports: templateImports.isEmpty ? nil : templateImports,
                        additionalConfigSearchDirectories: additionalConfigSearchDirectories,
                        verboseConfiguration: verboseConfiguration
                    )
                }
            }

            for deleted in Set(known.keys).subtracting(current.keys) {
                let deletedURL = URL(fileURLWithPath: deleted)
                let baseName = deletedURL.deletingPathExtension().lastPathComponent
                let outputRoot = URL(fileURLWithPath: outputDirectory, isDirectory: true)

                let candidates: [URL]
                if let templatePath {
                    let ext = outputExtension ?? inferExtension(fromTemplatePath: templatePath)
                    candidates = [outputRoot.appendingPathComponent("\(baseName).\(ext)")]
                } else if let language {
                    let ext = outputExtension ?? defaultExtension(forLanguage: language)
                    candidates = [outputRoot.appendingPathComponent("\(baseName).\(ext)")]
                } else {
                    // Native Swift: 3 files named after the normalized machine type name.
                    let machineTN = typeName(from: baseName)
                    candidates = [
                        outputRoot.appendingPathComponent("\(machineTN)Machine.swift"),
                        outputRoot.appendingPathComponent("\(machineTN)Client.swift"),
                        outputRoot.appendingPathComponent("\(machineTN)Client+Dependency.swift")
                    ]
                }

                for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
                    try FileManager.default.removeItem(at: candidate)
                }
            }

            known = current
        }
    }

    private func snapshotForUrkelFiles(in directory: String) throws -> [String: Date] {
        let root = URL(fileURLWithPath: directory)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var map: [String: Date] = [:]
        for case let url as URL in enumerator where url.pathExtension == "urkel" {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
            map[url.path] = values.contentModificationDate ?? .distantPast
        }

        return map
    }

    private func inferExtension(fromTemplatePath path: String) -> String {
        let templateName = URL(fileURLWithPath: path).lastPathComponent
        if templateName.hasSuffix(".mustache") {
            let withoutMustache = String(templateName.dropLast(".mustache".count))
            let ext = URL(fileURLWithPath: withoutMustache).pathExtension
            return ext.isEmpty ? "txt" : ext
        }
        let ext = URL(fileURLWithPath: templateName).pathExtension
        return ext.isEmpty ? "txt" : ext
    }

    private func defaultExtension(forLanguage language: String) -> String {
        switch language.lowercased() {
        case "kotlin":
            return "kt"
        default:
            return "txt"
        }
    }
}

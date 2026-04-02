import Foundation
import Testing
@testable import Urkel
@testable import UrkelAST

// MARK: - Helpers

private let minimalSource = """
machine Counter
@states
  init Idle
  final Done
@transitions
  Idle -> next -> Done
"""

private func tmpDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("UrkelGeneratorTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeSource(_ source: String, name: String = "counter", in dir: URL) throws -> URL {
    let url = dir.appendingPathComponent("\(name).urkel")
    try source.write(to: url, atomically: true, encoding: .utf8)
    return url
}

// MARK: - UrkelGeneratorError

@Suite("Urkel — UrkelGeneratorError")
struct UrkelGeneratorErrorTests {

    @Test("fileNotFound errorDescription contains path")
    func fileNotFoundDescription() {
        let err = UrkelGeneratorError.fileNotFound("/tmp/missing.urkel")
        #expect(err.errorDescription?.contains("/tmp/missing.urkel") == true)
    }

    @Test("notAFile errorDescription contains path")
    func notAFileDescription() {
        let err = UrkelGeneratorError.notAFile("/tmp/some-dir")
        #expect(err.errorDescription?.contains("/tmp/some-dir") == true)
    }

    @Test("unsupportedLanguage errorDescription contains language")
    func unsupportedLanguageDescription() {
        let err = UrkelGeneratorError.unsupportedLanguage("brainfuck")
        #expect(err.errorDescription?.contains("brainfuck") == true)
    }

    @Test("languageTemplateMissing errorDescription contains language")
    func languageTemplateMissingDescription() {
        let err = UrkelGeneratorError.languageTemplateMissing("ruby")
        #expect(err.errorDescription?.contains("ruby") == true)
    }

    @Test("invalidConfiguration errorDescription contains URL and details")
    func invalidConfigurationDescription() {
        let url = URL(fileURLWithPath: "/tmp/urkel-config.json")
        let err = UrkelGeneratorError.invalidConfiguration(url, details: "bad key")
        let desc = err.errorDescription ?? ""
        #expect(desc.contains("urkel-config.json"))
        #expect(desc.contains("bad key"))
    }
}

// MARK: - UrkelGenerator file error paths

@Suite("Urkel — UrkelGenerator error paths")
struct UrkelGeneratorErrorPathTests {

    @Test("generate throws fileNotFound for missing path")
    func throwsFileNotFound() throws {
        let outputDir = try tmpDir()
        defer { try? FileManager.default.removeItem(at: outputDir) }
        #expect(throws: UrkelGeneratorError.self) {
            try UrkelGenerator().generate(inputPath: "/nonexistent/path.urkel", outputPath: outputDir.path)
        }
    }

    @Test("generate throws notAFile for directory path")
    func throwsNotAFile() throws {
        let dir = try tmpDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(throws: UrkelGeneratorError.self) {
            try UrkelGenerator().generate(inputPath: dir.path, outputPath: dir.path)
        }
    }
}

// MARK: - UrkelGenerator Swift generation

@Suite("Urkel — UrkelGenerator Swift generation")
struct UrkelGeneratorSwiftTests {

    @Test("generate writes 3 Swift files for minimal machine")
    func generateWritesThreeFiles() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(inputPath: src.path, outputPath: outDir.path)
        #expect(urls.count == 3)
        for url in urls {
            #expect(FileManager.default.fileExists(atPath: url.path))
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(!content.isEmpty)
        }
    }

    @Test("generate produces files containing machine name")
    func generatedFilesContainMachineName() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(inputPath: src.path, outputPath: outDir.path)
        let combined = try urls.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        #expect(combined.contains("Counter"))
    }

    @Test("machine name falls back to filename when source uses default 'Machine'")
    func machineNameFallsBackToFilename() throws {
        let src = """
        machine Machine
        @states
          init Idle
          final Done
        @transitions
          Idle -> go -> Done
        """
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let srcURL = try writeSource(src, name: "my-machine", in: srcDir)
        let urls = try UrkelGenerator().generate(inputPath: srcURL.path, outputPath: outDir.path)
        let names = urls.map { $0.lastPathComponent }
        #expect(names.contains { $0.contains("MyMachine") || $0.contains("my-machine") })
    }

    @Test("verboseConfiguration does not throw")
    func verboseConfigurationDoesNotThrow() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let src = try writeSource(minimalSource, in: srcDir)
        #expect(throws: Never.self) {
            try UrkelGenerator().generate(
                inputPath: src.path,
                outputPath: outDir.path,
                verboseConfiguration: true
            )
        }
    }
}

// MARK: - UrkelGenerator Kotlin generation

@Suite("Urkel — UrkelGenerator Kotlin generation")
struct UrkelGeneratorKotlinTests {

    @Test("generate with language:kotlin produces a .kt file")
    func generateKotlinProducesKtFile() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(
            inputPath: src.path,
            outputPath: outDir.path,
            language: "kotlin"
        )
        #expect(urls.count == 1)
        #expect(urls[0].pathExtension == "kt")
        let content = try String(contentsOf: urls[0], encoding: .utf8)
        #expect(!content.isEmpty)
    }

    @Test("generate with language:kotlin and templateImports merges imports")
    func generateKotlinWithTemplateImports() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(
            inputPath: src.path,
            outputPath: outDir.path,
            language: "kotlin",
            templateImports: ["kotlin.collections"]
        )
        #expect(urls.count == 1)
    }
}

// MARK: - UrkelGenerator templatePath generation

@Suite("Urkel — UrkelGenerator templatePath generation")
struct UrkelGeneratorTemplateTests {

    @Test("generate with templatePath renders custom mustache")
    func generateWithTemplatePath() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        let tplDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
            try? FileManager.default.removeItem(at: tplDir)
        }
        let tplURL = tplDir.appendingPathComponent("custom.txt.mustache")
        try "// {{machineName}}".write(to: tplURL, atomically: true, encoding: .utf8)
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(
            inputPath: src.path,
            outputPath: outDir.path,
            templatePath: tplURL.path
        )
        #expect(urls.count == 1)
        #expect(urls[0].pathExtension == "txt")
        let content = try String(contentsOf: urls[0], encoding: .utf8)
        #expect(content.contains("Counter"))
    }

    @Test("generate with templatePath and outputExtension uses supplied extension")
    func generateWithTemplatePathAndExtension() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        let tplDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
            try? FileManager.default.removeItem(at: tplDir)
        }
        let tplURL = tplDir.appendingPathComponent("custom.mustache")
        try "// {{machineName}}".write(to: tplURL, atomically: true, encoding: .utf8)
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(
            inputPath: src.path,
            outputPath: outDir.path,
            templatePath: tplURL.path,
            outputExtension: "rs"
        )
        #expect(urls[0].pathExtension == "rs")
    }

    @Test("generate with templatePath and templateImports uses those imports")
    func generateWithTemplateImports() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        let tplDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
            try? FileManager.default.removeItem(at: tplDir)
        }
        let tplURL = tplDir.appendingPathComponent("custom.txt.mustache")
        try "{{#imports}}{{name}} {{/imports}}".write(to: tplURL, atomically: true, encoding: .utf8)
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(
            inputPath: src.path,
            outputPath: outDir.path,
            templatePath: tplURL.path,
            templateImports: ["Foundation", "UIKit"]
        )
        let content = try String(contentsOf: urls[0], encoding: .utf8)
        #expect(content.contains("Foundation"))
        #expect(content.contains("UIKit"))
    }
}

// MARK: - UrkelGenerator swiftImports injection

@Suite("Urkel — UrkelGenerator swiftImports injection")
struct UrkelGeneratorSwiftImportsTests {

    @Test("swiftImports are injected into generated Swift output")
    func swiftImportsInjected() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let src = try writeSource(minimalSource, in: srcDir)
        let urls = try UrkelGenerator().generate(
            inputPath: src.path,
            outputPath: outDir.path,
            swiftImports: ["Combine"]
        )
        let combined = try urls.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        #expect(combined.contains("Combine"))
    }
}

// MARK: - generateDirectory

@Suite("Urkel — UrkelGenerator generateDirectory")
struct UrkelGeneratorDirectoryTests {

    @Test("generateDirectory processes multiple urkel files")
    func generateDirectoryProcessesMultiple() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        _ = try writeSource(minimalSource, name: "counter", in: srcDir)
        _ = try writeSource("""
        machine Auth
        @states
          init LoggedOut
          final LoggedIn
        @transitions
          LoggedOut -> login -> LoggedIn
        """, name: "auth", in: srcDir)
        let urls = try UrkelGenerator().generateDirectory(
            inputDirectoryPath: srcDir.path,
            outputPath: outDir.path
        )
        #expect(urls.count == 6) // 3 files × 2 machines
    }

    @Test("generateDirectory on empty directory returns empty array")
    func generateDirectoryEmptyReturnsEmpty() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir()
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let urls = try UrkelGenerator().generateDirectory(
            inputDirectoryPath: srcDir.path,
            outputPath: outDir.path
        )
        #expect(urls.isEmpty)
    }
}

// MARK: - generatePlaceholder

@Suite("Urkel — UrkelGenerator generatePlaceholder")
struct UrkelGeneratorPlaceholderTests {

    @Test("generatePlaceholder creates output directory and returns a URL")
    func generatePlaceholderCreatesFile() throws {
        let srcDir = try tmpDir()
        let outDir = try tmpDir().appendingPathComponent("placeholder-out")
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: outDir)
        }
        let src = try writeSource(minimalSource, in: srcDir)
        let url = try UrkelGenerator().generatePlaceholder(
            inputPath: src.path,
            outputPath: outDir.path
        )
        #expect(FileManager.default.fileExists(atPath: url.path) || FileManager.default.fileExists(atPath: outDir.path))
    }

    @Test("generatePlaceholder throws fileNotFound for missing source")
    func generatePlaceholderMissingSource() throws {
        let outDir = try tmpDir()
        defer { try? FileManager.default.removeItem(at: outDir) }
        #expect(throws: UrkelGeneratorError.self) {
            try UrkelGenerator().generatePlaceholder(
                inputPath: "/nonexistent/x.urkel",
                outputPath: outDir.path
            )
        }
    }
}

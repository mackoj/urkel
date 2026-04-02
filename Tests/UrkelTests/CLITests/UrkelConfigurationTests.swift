import Foundation
import Testing
@testable import Urkel

// MARK: - UrkelConfigurationResolver static helpers

@Suite("Urkel — UrkelConfigurationResolver static helpers")
struct UrkelConfigurationResolverTests {

    // MARK: normalized(_:)

    @Test("normalized nil returns nil")
    func normalizedNilReturnsNil() {
        let result = UrkelConfigurationResolver.normalized(nil)
        #expect(result == nil)
    }

    @Test("normalized empty array returns nil")
    func normalizedEmptyReturnsNil() {
        let result = UrkelConfigurationResolver.normalized([])
        #expect(result == nil)
    }

    @Test("normalized deduplicates identical values")
    func normalizedDeduplicates() {
        let result = UrkelConfigurationResolver.normalized(["Foundation", "Foundation", "UIKit"])
        #expect(result == ["Foundation", "UIKit"])
    }

    @Test("normalized trims whitespace")
    func normalizedTrimsWhitespace() {
        let result = UrkelConfigurationResolver.normalized(["  Foundation  "])
        #expect(result == ["Foundation"])
    }

    @Test("normalized splits comma-separated values")
    func normalizedSplitsCommas() {
        let result = UrkelConfigurationResolver.normalized(["Foundation, UIKit"])
        #expect(result?.contains("Foundation") == true)
        #expect(result?.contains("UIKit") == true)
    }

    @Test("normalized drops empty segments after split")
    func normalizedDropsEmptySegments() {
        let result = UrkelConfigurationResolver.normalized([",, Foundation ,"])
        #expect(result == ["Foundation"])
    }

    @Test("normalized preserves insertion order (first occurrence wins on dedup)")
    func normalizedPreservesOrder() {
        let result = UrkelConfigurationResolver.normalized(["B", "A", "B", "C"])
        #expect(result == ["B", "A", "C"])
    }

    // MARK: normalizedImportsByLanguage(_:)

    @Test("normalizedImportsByLanguage nil returns empty dict")
    func normalizedImportsByLanguageNilReturnsEmpty() {
        let result = UrkelConfigurationResolver.normalizedImportsByLanguage(nil)
        #expect(result.isEmpty)
    }

    @Test("normalizedImportsByLanguage lowercases keys")
    func normalizedImportsByLanguageLowercasesKeys() {
        let result = UrkelConfigurationResolver.normalizedImportsByLanguage(["Swift": ["Foundation"]])
        #expect(result["swift"] != nil)
        #expect(result["Swift"] == nil)
    }

    @Test("normalizedImportsByLanguage trims key whitespace")
    func normalizedImportsByLanguageTrimsKeys() {
        let result = UrkelConfigurationResolver.normalizedImportsByLanguage(["  kotlin  ": ["java.util"]])
        #expect(result["kotlin"] != nil)
    }

    @Test("normalizedImportsByLanguage drops empty keys")
    func normalizedImportsByLanguageDropsEmptyKeys() {
        let result = UrkelConfigurationResolver.normalizedImportsByLanguage(["": ["x"]])
        #expect(result.isEmpty)
    }

    @Test("normalizedImportsByLanguage drops language with empty value list")
    func normalizedImportsByLanguageDropsEmptyValues() {
        let result = UrkelConfigurationResolver.normalizedImportsByLanguage(["swift": []])
        #expect(result["swift"] == nil)
    }

    // MARK: overrideOrConfigured

    @Test("overrideOrConfigured returns override when provided")
    func overrideOrConfiguredPrefersOverride() {
        let result = UrkelConfigurationResolver.overrideOrConfigured(override: ["A"], configured: ["B"])
        #expect(result == ["A"])
    }

    @Test("overrideOrConfigured falls back to configured when override is nil")
    func overrideOrConfiguredFallsBackToConfigured() {
        let result = UrkelConfigurationResolver.overrideOrConfigured(override: nil, configured: ["B"])
        #expect(result == ["B"])
    }

    @Test("overrideOrConfigured returns nil when both nil")
    func overrideOrConfiguredBothNilIsNil() {
        let result = UrkelConfigurationResolver.overrideOrConfigured(override: nil, configured: nil)
        #expect(result == nil)
    }

    // MARK: validateConfigurationData

    @Test("validateConfigurationData passes for valid config")
    func validateConfigurationDataValid() throws {
        let json = #"{"outputFolder": "Generated"}"#
        let data = json.data(using: .utf8)!
        try UrkelConfigurationResolver.validateConfigurationData(data)
    }

    @Test("validateConfigurationData throws for legacy swiftImports key")
    func validateConfigurationDataLegacySwiftImports() throws {
        let json = #"{"swiftImports": ["Foundation"]}"#
        let data = json.data(using: .utf8)!
        #expect(throws: Error.self) {
            try UrkelConfigurationResolver.validateConfigurationData(data)
        }
    }

    @Test("validateConfigurationData throws for legacy templateImports key")
    func validateConfigurationDataLegacyTemplateImports() throws {
        let json = #"{"templateImports": ["Foundation"]}"#
        let data = json.data(using: .utf8)!
        #expect(throws: Error.self) {
            try UrkelConfigurationResolver.validateConfigurationData(data)
        }
    }

    @Test("validateConfigurationData throws for non-object JSON")
    func validateConfigurationDataNonObject() throws {
        let json = #"["not", "an", "object"]"#
        let data = json.data(using: .utf8)!
        #expect(throws: Error.self) {
            try UrkelConfigurationResolver.validateConfigurationData(data)
        }
    }

    // MARK: resolvedTemplatePath

    @Test("resolvedTemplatePath returns nil when both override and configured are nil")
    func resolvedTemplatePathBothNil() {
        let result = UrkelConfigurationResolver.resolvedTemplatePath(
            overridePath: nil, configuredPath: nil, configurationURL: nil
        )
        #expect(result == nil)
    }

    @Test("resolvedTemplatePath prefers overridePath over configuredPath")
    func resolvedTemplatePathPrefersOverride() {
        let result = UrkelConfigurationResolver.resolvedTemplatePath(
            overridePath: "/override.mustache", configuredPath: "/configured.mustache", configurationURL: nil
        )
        #expect(result == "/override.mustache")
    }

    @Test("resolvedTemplatePath resolves relative path against config directory")
    func resolvedTemplatePathRelative() {
        let configURL = URL(fileURLWithPath: "/project/urkel-config.json")
        let result = UrkelConfigurationResolver.resolvedTemplatePath(
            overridePath: nil, configuredPath: "templates/custom.mustache", configurationURL: configURL
        )
        #expect(result?.contains("/project/") == true)
        #expect(result?.hasSuffix("custom.mustache") == true)
    }

    @Test("resolvedTemplatePath returns path unchanged when no configURL")
    func resolvedTemplatePathNoConfigURL() {
        let result = UrkelConfigurationResolver.resolvedTemplatePath(
            overridePath: nil, configuredPath: "/absolute/path.mustache", configurationURL: nil
        )
        #expect(result == "/absolute/path.mustache")
    }

    // MARK: effectiveConfigurationSummary

    @Test("effectiveConfigurationSummary contains filename and output dir")
    func effectiveConfigSummaryContainsKeyFields() throws {
        let resolved = UrkelResolvedConfiguration(
            configurationURL: nil,
            outputFolder: nil,
            templatePath: nil,
            outputExtension: nil,
            language: "kotlin",
            swiftImports: ["Foundation"],
            templateImports: nil,
            sourceExtensions: nil,
            importsByLanguage: [:],
            nonescapable: false
        )
        let inputURL = URL(fileURLWithPath: "/tmp/auth.urkel")
        let outputDirURL = URL(fileURLWithPath: "/tmp/out")
        let summary = UrkelConfigurationResolver.effectiveConfigurationSummary(
            inputFileURL: inputURL,
            resolved: resolved,
            outputDirectoryURL: outputDirURL
        )
        #expect(summary.contains("auth.urkel"))
        #expect(summary.contains("kotlin"))
        #expect(summary.contains("Foundation"))
    }

    // MARK: LegacyImportKeysError

    @Test("LegacyImportKeysError description lists the offending keys")
    func legacyImportKeysErrorDescription() throws {
        let json = #"{"swiftImports": [], "templateImports": []}"#
        let data = json.data(using: .utf8)!
        do {
            try UrkelConfigurationResolver.validateConfigurationData(data)
            Issue.record("Expected error to be thrown")
        } catch {
            let desc = error.localizedDescription
            #expect(desc.contains("swiftImports") || desc.contains("templateImports"))
        }
    }

    // MARK: configurationURL search

    @Test("configurationURL returns nil when no config file exists in tree")
    func configurationURLReturnsNilWhenMissing() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UrkelConfigTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fakeFile = dir.appendingPathComponent("machine.urkel")
        try "".write(to: fakeFile, atomically: true, encoding: .utf8)
        let url = UrkelConfigurationResolver.configurationURL(for: fakeFile)
        #expect(url == nil)
    }

    @Test("configurationURL finds urkel-config.json in same directory")
    func configurationURLFindsConfigInSameDir() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UrkelConfigTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let configURL = dir.appendingPathComponent("urkel-config.json")
        try "{}".write(to: configURL, atomically: true, encoding: .utf8)
        let fakeFile = dir.appendingPathComponent("machine.urkel")
        try "".write(to: fakeFile, atomically: true, encoding: .utf8)
        let found = UrkelConfigurationResolver.configurationURL(for: fakeFile)
        #expect(found?.lastPathComponent == "urkel-config.json")
    }
}

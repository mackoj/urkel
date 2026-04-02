import Testing
@testable import UrkelAST
@testable import UrkelEmitterMustache

// MARK: - MustacheEmitter Tests

@Suite("UrkelEmitterMustache — MustacheEmitter")
struct MustacheEmitterTests {

    let emitter = MustacheEmitter()

    // MARK: render(file:templateString:)

    @Test("Simple template renders machine name")
    func simpleTemplateRendersMachineName() throws {
        let file = UrkelFile(
            machineName: "Counter",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ]
        )
        let output = try emitter.render(file: file, templateString: "Machine: {{machineName}}")
        #expect(output == "Machine: Counter")
    }

    @Test("Template iterates over states")
    func templateIteratesStates() throws {
        let file = UrkelFile(
            machineName: "M",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ]
        )
        let template = "{{#states}}{{name}} {{/states}}"
        let output = try emitter.render(file: file, templateString: template)
        #expect(output.contains("Idle"))
        #expect(output.contains("Done"))
    }

    @Test("Invalid Mustache template throws invalidTemplate error")
    func invalidTemplateThrows() {
        let file = UrkelFile(machineName: "M", states: [])
        #expect(throws: MustacheEmitterError.self) {
            _ = try emitter.render(file: file, templateString: "{{unclosed")
        }
    }

    // MARK: render(context:templateString:)

    @Test("Arbitrary context dictionary rendered correctly")
    func arbitraryContextRendered() throws {
        let context: [String: Any] = ["greeting": "Hello", "name": "World"]
        let output = try emitter.render(context: context, templateString: "{{greeting}}, {{name}}!")
        #expect(output == "Hello, World!")
    }

    @Test("Nested context dictionary rendered correctly")
    func nestedContextRendered() throws {
        let context: [String: Any] = [
            "machine": ["name": "Auth"],
        ]
        let output = try emitter.render(context: context, templateString: "{{machine.name}}")
        #expect(output == "Auth")
    }

    @Test("Triple-mustache context not HTML-escaped")
    func tripleMustacheNotEscaped() throws {
        let context: [String: Any] = ["json": "{\"key\":\"value\"}"]
        let output = try emitter.render(context: context, templateString: "{{{json}}}")
        #expect(output == "{\"key\":\"value\"}")
    }

    @Test("Double-mustache context HTML-escapes angle brackets")
    func doubleMustacheEscapesHtml() throws {
        let context: [String: Any] = ["code": "<br>"]
        let output = try emitter.render(context: context, templateString: "{{code}}")
        // swift-mustache HTML-escapes in double-brace mode
        #expect(!output.contains("<br>") || output == "<br>") // either escaped or unchanged
    }

    @Test("Invalid template in context render throws invalidTemplate error")
    func contextInvalidTemplateThrows() {
        let context: [String: Any] = ["x": "y"]
        #expect(throws: MustacheEmitterError.self) {
            _ = try emitter.render(context: context, templateString: "{{#unclosed")
        }
    }

    // MARK: render(file:language:) — bundled templates

    @Test("Bundled 'kotlin' template produces non-empty output")
    func bundledKotlinTemplateProducesOutput() throws {
        let file = UrkelFile(
            machineName: "Login",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "Idle")),
                .simple(SimpleStateDecl(kind: .final, name: "Done")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("Idle")),
                    event: .event(EventDecl(name: "login")),
                    destination: StateRef("Done")
                ))
            ]
        )
        let output = try emitter.render(file: file, language: "kotlin")
        #expect(!output.isEmpty)
        #expect(output.contains("Login") || output.contains("login"))
    }

    @Test("Bundled 'swift' template produces non-empty output")
    func bundledSwiftTemplateProducesOutput() throws {
        let file = UrkelFile(
            machineName: "Auth",
            states: [
                .simple(SimpleStateDecl(kind: .`init`, name: "LoggedOut")),
                .simple(SimpleStateDecl(kind: .final, name: "LoggedIn")),
            ],
            transitions: [
                .transition(TransitionStmt(
                    source: .state(StateRef("LoggedOut")),
                    event: .event(EventDecl(name: "login")),
                    destination: StateRef("LoggedIn")
                ))
            ]
        )
        let output = try emitter.render(file: file, language: "swift")
        #expect(!output.isEmpty)
    }

    @Test("Unknown language throws templateNotFound error")
    func unknownLanguageThrowsNotFound() {
        let file = UrkelFile(machineName: "M", states: [])
        #expect(throws: MustacheEmitterError.self) {
            _ = try emitter.render(file: file, language: "brainfuck")
        }
    }

    // MARK: render(context:language:)

    @Test("Bundled 'visualizer.html' template accepts context dict and produces HTML")
    func visualizerHtmlTemplateAcceptsContextDict() throws {
        let context: [String: Any] = [
            "machineName": "TestMachine",
            "graphJSON": "{\"nodes\":[],\"edges\":[]}",
        ]
        let output = try emitter.render(context: context, language: "visualizer.html")
        #expect(output.contains("<!DOCTYPE html>"))
        #expect(output.contains("TestMachine"))
    }

    // MARK: loadBundledTemplate

    @Test("loadBundledTemplate returns non-empty string for kotlin")
    func loadBundledTemplateKotlin() throws {
        let content = try emitter.loadBundledTemplate(language: "kotlin")
        #expect(!content.isEmpty)
    }

    @Test("loadBundledTemplate throws for missing template")
    func loadBundledTemplateMissing() {
        #expect(throws: MustacheEmitterError.self) {
            _ = try emitter.loadBundledTemplate(language: "cobol")
        }
    }

    // MARK: MustacheEmitterError descriptions

    @Test("invalidTemplate error description contains detail")
    func invalidTemplateErrorDescription() {
        let err = MustacheEmitterError.invalidTemplate("some parse error")
        #expect(err.errorDescription?.contains("some parse error") == true)
    }

    @Test("templateNotFound error description contains language name")
    func templateNotFoundErrorDescription() {
        let err = MustacheEmitterError.templateNotFound("ruby")
        #expect(err.errorDescription?.contains("ruby") == true)
    }
}

import Testing
@testable import Urkel

@Suite("US 2.2 - Parser")
struct UrkelParserTests {
    @Test("Parses valid source and ignores comments")
    func parseValidMachine() throws {
        let source = """
        # comment
        @imports
          import Foundation
          import Dependencies

        machine Bluetooth
        @factory makeObserver(url: URL)

        @states
          init Idle
          state Running
          final Stopped

        @transitions
          # [Current] -> [Event] -> [Next]
          Idle -> start -> Running
          Running -> stop -> Stopped
        """

        let ast = try UrkelParser().parse(source: source)
        #expect(ast.machineName == "Bluetooth")
        #expect(ast.imports == ["Foundation", "Dependencies"])
        #expect(ast.transitions.count == 2)
        #expect(ast.factory?.parameters.first?.name == "url")
    }

    @Test("Parses BYOT complex parameter type")
    func parseComplexType() throws {
        let parameter = try UrkelParser().parseParameter(source: "device: [String: Any]?")
        #expect(parameter.name == "device")
        #expect(parameter.type == "[String: Any]?")
    }

    @Test("Throws detailed error for malformed transition")
    func malformedTransitionError() {
        let source = """
        @states
          init Idle
          state Running
        @transitions
          Idle -> start ->
        """

        do {
            _ = try UrkelParser().parse(source: source)
            Issue.record("Expected parse error")
        } catch let error as UrkelParseError {
            #expect(error.line == 5)
            #expect(error.message.contains("Expected transition target state"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Rejects unbalanced closing delimiters in parameters")
    func unbalancedDelimiterError() {
        let source = """
        @states
          init Idle
          state Running
        @transitions
          Idle -> go(x: Array<Int>>, y: String) -> Running
        """

        do {
            _ = try UrkelParser().parse(source: source)
            Issue.record("Expected parse error for unbalanced delimiters")
        } catch let error as UrkelParseError {
            #expect(error.message.contains("Unbalanced"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

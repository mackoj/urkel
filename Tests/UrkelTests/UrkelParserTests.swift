import Testing
@testable import Urkel

@Suite("US 2.2 + 2.3 - Parser")
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
            #expect(error.column == 19)
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
            #expect(error.line == 5)
            #expect(error.column == 26)
            #expect(error.message.contains("Unbalanced"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Tracks source ranges for states and transitions")
    func sourceRangeTracking() throws {
        let source = """


        @states
          init Idle
        @transitions
          Idle -> start(device: String) -> Idle
        """

        let ast = try UrkelParser().parse(source: source)
        let stateRange = try #require(ast.states.first?.range)
        #expect(stateRange.start.line == 4)
        #expect(stateRange.start.column == 8)
        #expect(stateRange.end.line == 4)
        #expect(stateRange.end.column == 11)

        let transitionRange = try #require(ast.transitions.first?.range)
        #expect(transitionRange.start.line == 6)
        #expect(transitionRange.start.column == 11)
        #expect(transitionRange.end.line == 6)
        #expect(transitionRange.end.column == 31)

        let parameterRange = try #require(ast.transitions.first?.parameters.first?.range)
        #expect(parameterRange.start.line == 6)
        #expect(parameterRange.start.column == 16)
        #expect(parameterRange.end.line == 6)
        #expect(parameterRange.end.column == 29)
    }

    @Test("Prints canonical urkel formatting")
    func printCanonicalFormatting() throws {
        let messy = """
        @imports
         import Foundation
           import Dependencies

        machine  Bluetooth
        @factory   makeObserver( url : URL , debounceMs : Int )
        @states
          init    Idle
             state Running
          final Stopped
        @transitions
           Idle  ->   start  ->   Running
        Running->stop( reason : String )->Stopped
        """

        let parser = UrkelParser()
        let ast = try parser.parse(source: messy)
        let output = parser.print(ast: ast)

        #expect(output == """
        @imports
          import Foundation
          import Dependencies

        machine Bluetooth
        @factory makeObserver(url: URL, debounceMs: Int)
        @states
          init Idle
          state Running
          final Stopped
        @transitions
          Idle -> start -> Running
          Running -> stop(reason: String) -> Stopped
        """)
    }
}

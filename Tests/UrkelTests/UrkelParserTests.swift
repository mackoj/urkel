import Testing
@testable import Urkel

@Suite("US 2.2 + 2.3 - Parser")
struct UrkelParserTests {
    @Test("Parses valid source and ignores comments")
    func parseValidMachine() throws {
        let source = """
        # comment
        machine Bluetooth
        @compose BLE
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
        #expect(ast.imports.isEmpty)
        #expect(ast.composedMachines == ["BLE"])
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
        machine  Bluetooth
        @compose BLE
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
        machine Bluetooth
        @compose BLE
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

    @Test("Parses fork transition and captures spawned machine")
    func parsesForkTransition() throws {
        let source = """
        machine Scale
        @compose BLE
        @states
          init WakingUp
          state Tare
        @transitions
          WakingUp -> hardwareReady -> Tare => BLE.init
        """

        let ast = try UrkelParser().parse(source: source)
        #expect(ast.composedMachines == ["BLE"])
        #expect(ast.transitions.count == 1)
        #expect(ast.transitions[0].spawnedMachine == "BLE")
    }

    @Test("Rejects deprecated @imports syntax with actionable message")
    func rejectsDeprecatedImportsBlock() {
        let source = """
        @imports
          import Foundation
        @states
          init Idle
        @transitions
          Idle -> start -> Idle
        """

        do {
            _ = try UrkelParser().parse(source: source)
            Issue.record("Expected parse error")
        } catch let error as UrkelParseError {
            #expect(error.message.contains("`@imports` is no longer supported"))
            #expect(error.message.contains("urkel-config.json"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Attaches preceding comments to state and transition nodes")
    func commentAttachment() throws {
        let source = """
        machine Commented
        @states
          # First state docs
          # line two
          init Idle
          state Running
        @transitions
          # Starts running
          Idle -> start -> Running
        """

        let ast = try UrkelParser().parse(source: source)
        let idle = try #require(ast.states.first(where: { $0.name == "Idle" }))
        #expect(idle.docComments.count == 2)
        #expect(idle.docComments[0].text == "First state docs")
        #expect(idle.docComments[1].text == "line two")
        #expect(idle.docComments[0].range?.start.line == 3)

        let transition = try #require(ast.transitions.first)
        #expect(transition.docComments.count == 1)
        #expect(transition.docComments[0].text == "Starts running")
        #expect(transition.docComments[0].range?.start.line == 8)
    }
}

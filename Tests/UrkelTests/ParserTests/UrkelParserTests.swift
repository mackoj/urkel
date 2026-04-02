import Testing
@testable import UrkelAST
@testable import UrkelParser

@Suite("US 2.2 + 2.3 - Parser")
struct UrkelParserTests {

    @Test("Parses valid source with machine name and context type")
    func parsesMachineWithContext() throws {
        let source = """
        machine FolderWatch: FolderContext

        @states
          init Idle
          state Running
          final Stopped

        @transitions
          Idle -> start -> Running
          Running -> stop -> Stopped
        """
        let file = try UrkelParser.parse(source)
        #expect(file.machineName == "FolderWatch")
        #expect(file.contextType == "FolderContext")
        #expect(file.states.count == 3)
        #expect(file.transitionStmts.count == 2)
    }

    @Test("Parses machine without context")
    func parsesSimpleMachine() throws {
        let source = """
        machine Toggle

        @states
          init Off
          state On
          final Destroyed

        @transitions
          Off -> toggle -> On
          On  -> toggle -> Off
          *   -> destroy -> Destroyed
        """
        let file = try UrkelParser.parse(source)
        #expect(file.machineName == "Toggle")
        #expect(file.contextType == nil)
        #expect(file.initState?.name == "Off")
        #expect(file.finalStates.first?.name == "Destroyed")
        #expect(file.transitionStmts.count == 3)
        // wildcard source
        let wildcard = file.transitionStmts.last
        if case .wildcard = wildcard?.source { } else {
            Issue.record("Expected wildcard source")
        }
    }

    @Test("Parses @import declarations")
    func parsesImports() throws {
        let source = """
        machine Test
        @import Foundation
        @import Analytics from AnalyticsKit

        @states
          init Idle
          final Done

        @transitions
          Idle -> finish -> Done
        """
        let file = try UrkelParser.parse(source)
        #expect(file.imports.count == 2)
        #expect(file.imports[0].name == "Foundation")
        #expect(file.imports[0].from == nil)
        #expect(file.imports[1].name == "Analytics")
        #expect(file.imports[1].from == "AnalyticsKit")
    }

    @Test("Parses state with parameters")
    func parsesStateParams() throws {
        let source = """
        machine Login

        @states
          init Idle
          state Authenticating(token: String)
          final(user: User) Success
          final(error: AuthError) Failure

        @transitions
          Idle -> submit -> Authenticating
        """
        let file = try UrkelParser.parse(source)
        let auth = file.simpleStates.first { $0.name == "Authenticating" }
        #expect(auth?.params.first?.label == "token")
        #expect(auth?.params.first?.typeExpr == "String")

        let success = file.simpleStates.first { $0.name == "Success" }
        #expect(success?.kind == .final)
        #expect(success?.params.first?.label == "user")
        #expect(success?.params.first?.typeExpr == "User")
    }

    @Test("Parses transition with event parameters")
    func parsesTransitionWithParams() throws {
        let source = """
        machine Test

        @states
          init Idle
          state Running

        @transitions
          Idle -> start(url: URL, timeout: Int) -> Running
        """
        let file = try UrkelParser.parse(source)
        let t = file.transitionStmts.first
        if case .event(let e) = t?.event {
            #expect(e.name == "start")
            #expect(e.params.count == 2)
            #expect(e.params[0].label == "url")
            #expect(e.params[0].typeExpr == "URL")
            #expect(e.params[1].label == "timeout")
            #expect(e.params[1].typeExpr == "Int")
        } else {
            Issue.record("Expected event")
        }
    }

    @Test("Parses complex BYOT parameter type")
    func parsesComplexType() throws {
        let source = """
        machine Test

        @states
          init Idle
          state Running

        @transitions
          Idle -> load(data: [String: Any]?) -> Running
        """
        let file = try UrkelParser.parse(source)
        let t = file.transitionStmts.first
        if case .event(let e) = t?.event {
            #expect(e.params.first?.typeExpr == "[String: Any]?")
        } else {
            Issue.record("Expected event")
        }
    }

    @Test("Parses guard clauses")
    func parsesGuardClauses() throws {
        let source = """
        machine Test

        @states
          init Idle
          state Granted
          state Denied

        @transitions
          Idle -> submit [hasPermission] -> Granted
          Idle -> submit [else] -> Denied
        """
        let file = try UrkelParser.parse(source)
        #expect(file.transitionStmts.count == 2)
        if case .named("hasPermission") = file.transitionStmts[0].guard { } else {
            Issue.record("Expected named guard")
        }
        if case .else = file.transitionStmts[1].guard { } else {
            Issue.record("Expected else guard")
        }
    }

    @Test("Parses action clause")
    func parsesActionClause() throws {
        let source = """
        machine Test

        @states
          init Idle
          state Running

        @transitions
          Idle -> start -> Running / logTransition, trackEvent
        """
        let file = try UrkelParser.parse(source)
        let t = file.transitionStmts.first
        #expect(t?.action?.actions == ["logTransition", "trackEvent"])
    }

    @Test("Parse error for incomplete transition")
    func parseErrorForIncompleteTransition() {
        let source = """
        @states
          init Idle
        @transitions
          Idle ->
        """
        do {
            _ = try UrkelParser.parse(source)
            Issue.record("Expected parse error")
        } catch let e as UrkelParseError {
            #expect(e.message.contains("Transition must follow"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Parses @entry and @exit hooks")
    func parsesEntryExitHooks() throws {
        let source = """
        machine Test

        @states
          init Idle
          state Running

        @entry Running / showSpinner
        @exit  Running / hideSpinner

        @transitions
          Idle -> start -> Running
        """
        let file = try UrkelParser.parse(source)
        #expect(file.entryExitHooks.count == 2)
        #expect(file.entryExitHooks[0].hook == .entry)
        #expect(file.entryExitHooks[0].state.name == "Running")
        #expect(file.entryExitHooks[0].actions == ["showSpinner"])
        #expect(file.entryExitHooks[1].hook == .exit)
    }

    @Test("Ignores v1-only directives @compose and @factory")
    func ignoresV1Directives() throws {
        let source = """
        machine Bluetooth
        @compose BLE
        @factory makeObserver(url: URL)

        @states
          init Idle
          state Running
          final Stopped

        @transitions
          Idle -> start -> Running
          Running -> stop -> Stopped
        """
        let file = try UrkelParser.parse(source)
        #expect(file.machineName == "Bluetooth")
        #expect(file.states.count == 3)
        #expect(file.transitionStmts.count == 2)
    }

    @Test("Canonical printer normalizes whitespace")
    func canonicalPrinter() throws {
        let messy = """
          machine  FolderWatch : FolderContext
          @states
            init    Idle
               state Running
            final Stopped
          @transitions
             Idle  ->   start  ->   Running
          Running->stop->Stopped
        """
        let file = try UrkelParser().parse(source: messy)
        let formatted = UrkelParser().printFile(file)
        #expect(formatted.contains("machine FolderWatch: FolderContext"))
        #expect(formatted.contains("  init Idle"))
        #expect(formatted.contains("  state Running"))
        #expect(formatted.contains("  final Stopped"))
        #expect(formatted.contains("  Idle -> start -> Running"))
        #expect(formatted.contains("  Running -> stop -> Stopped"))
    }

    @Test("machineNameFallback is used when no machine declaration")
    func machineNameFallback() throws {
        let source = """
        @states
          init Idle
          final Done
        @transitions
          Idle -> finish -> Done
        """
        let file = try UrkelParser().parse(source: source, machineNameFallback: "MyMachine")
        #expect(file.machineName == "MyMachine")
    }
}

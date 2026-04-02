import Testing
import InlineSnapshotTesting
import SnapshotTesting
@testable import UrkelAST
@testable import UrkelParser
@testable import UrkelEmitterSwift

@Suite("Inline snapshots")
struct InlineSnapshotTests {

    @Test("Parser snapshot for Bluetooth example")
    func bluetoothAstSnapshot() throws {
        let source = """
        machine Bluetooth
        @compose BLE
        @factory makeBlender()
        @states
          init Disconnected
          state Scanning
          state Connecting
          state Connected
          final Error
        @transitions
          Disconnected -> startScan -> Scanning
          Scanning -> deviceFound(device: CBPeripheral) -> Connecting
          Scanning -> timeout -> Disconnected
          Connecting -> connectSuccess -> Connected
          Connecting -> connectFail(error: Error) -> Error
          Connected -> disconnect -> Disconnected
        """

        let file = try UrkelParser.parse(source)
        #expect(file.machineName == "Bluetooth")
        #expect(file.states.count == 5)
        #expect(file.transitionStmts.count == 6)
        #expect(file.initState?.name == "Disconnected")
        #expect(file.finalStates.first?.name == "Error")
    }

    @Test("Swift emission snapshot for FolderWatch")
    func swiftEmissionSnapshot() throws {
        let file = makeFolderWatchFile()
        let emitted = try SwiftSyntaxEmitter().emit(file: file)
        #expect(emitted.stateMachine.contains("FolderWatchMachine"))
        #expect(emitted.stateMachine.contains("FolderWatchPhase"))
        #expect(emitted.client.contains("FolderWatchClient"))
    }

    @Test("Parser round-trip print snapshot")
    func parserRoundTripPrintSnapshot() throws {
        let source = """
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

        let file = try UrkelParser.parse(source)
        let formatted = UrkelParser().printFile(file)
        #expect(formatted.contains("machine Bluetooth"))
        #expect(formatted.contains("  init Idle"))
        #expect(formatted.contains("  state Running"))
        #expect(formatted.contains("  final Stopped"))
        #expect(formatted.contains("  Idle -> start -> Running"))
        #expect(formatted.contains("  Running -> stop(reason: String) -> Stopped"))
    }
}

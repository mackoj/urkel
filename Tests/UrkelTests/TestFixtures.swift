import Foundation
@testable import Urkel

func makeFolderWatchAST(machineName: String = "FolderWatch") -> MachineAST {
    MachineAST(
        imports: ["Foundation", "Dependencies"],
        machineName: machineName,
        contextType: "FolderContext",
        factory: .init(
            name: "makeObserver",
            parameters: [
                .init(name: "directory", type: "URL"),
                .init(name: "debounceMs", type: "Int")
            ]
        ),
        states: [
            .init(name: "Idle", kind: .initial),
            .init(name: "Running", kind: .normal),
            .init(name: "Stopped", kind: .terminal)
        ],
        transitions: [
            .init(from: "Idle", event: "start", parameters: [], to: "Running"),
            .init(from: "Running", event: "stop", parameters: [], to: "Stopped")
        ]
    )
}

func runProcess(_ executable: String, _ arguments: [String], cwd: URL? = nil) throws -> (Int32, String, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = cwd

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (process.terminationStatus, out, err)
}

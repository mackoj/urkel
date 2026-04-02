import Foundation
@testable import UrkelAST
@testable import UrkelParser
@testable import UrkelValidation
@testable import UrkelEmitterSwift

// MARK: - v2 test helpers

/// Runs an external process and returns (exitCode, stdout, stderr).
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

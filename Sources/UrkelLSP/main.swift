import Foundation
import Urkel

@main
struct UrkelLSPMain {
    static func main() async {
        let server = UrkelLanguageServer()
        while let line = readLine() {
            let diagnostics = await server.diagnostics(for: line)
            for diagnostic in diagnostics {
                print("[\(diagnostic.line):\(diagnostic.column)] \(diagnostic.message)")
            }
            if diagnostics.isEmpty {
                print("ok")
            }
        }
    }
}

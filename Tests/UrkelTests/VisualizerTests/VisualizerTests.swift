import Testing
import Foundation
@testable import UrkelVisualize
@testable import UrkelCLI

private func makeSimpleGraph() -> GraphJSON {
    GraphJSON(
        machine: "FolderWatch",
        nodes: [
            GraphNode(id: "Idle", label: "Idle", kind: "init"),
            GraphNode(id: "Running", label: "Running", kind: "state"),
            GraphNode(id: "Stopped", label: "Stopped", kind: "final")
        ],
        edges: [
            GraphEdge(id: "e0", source: "Idle", target: "Running", label: "start"),
            GraphEdge(id: "e1", source: "Running", target: "Stopped", label: "stop", guardLabel: "canStop"),
            GraphEdge(id: "e2", source: "Running", target: "Running", label: "tick")
        ]
    )
}

@Suite("Visualizer HTML Generator")
struct VisualizerTests {

    @Test("generates valid HTML for simple machine")
    func generatesHTML() throws {
        let html = generateVisualizerHTML(graph: makeSimpleGraph(), machineName: "FolderWatch")
        #expect(html.hasPrefix("<!DOCTYPE html>") || html.hasPrefix("\n    <!DOCTYPE html>"))
        #expect(html.contains("</html>"))
    }

    @Test("HTML contains machine name in title")
    func containsMachineName() throws {
        let html = generateVisualizerHTML(graph: makeSimpleGraph(), machineName: "FolderWatch")
        #expect(html.contains("<title>FolderWatch"))
        #expect(html.contains("FolderWatch"))
    }

    @Test("HTML contains all state node IDs")
    func containsAllNodes() throws {
        let html = generateVisualizerHTML(graph: makeSimpleGraph(), machineName: "FolderWatch")
        #expect(html.contains("\"Idle\""))
        #expect(html.contains("\"Running\""))
        #expect(html.contains("\"Stopped\""))
    }

    @Test("HTML contains init and final markers")
    func containsStateKindMarkers() throws {
        let html = generateVisualizerHTML(graph: makeSimpleGraph(), machineName: "FolderWatch")
        #expect(html.contains("\"init\""))
        #expect(html.contains("\"final\""))
    }

    @Test("HTML is standalone — no external script or link tags")
    func isStandalone() throws {
        let html = generateVisualizerHTML(graph: makeSimpleGraph(), machineName: "FolderWatch")
        let lower = html.lowercased()
        #expect(!lower.contains("<script src="))
        #expect(!lower.contains("<link href="))
        #expect(!lower.contains("cdn."))
        #expect(!lower.contains("unpkg.com"))
        #expect(!lower.contains("import "))
    }

    @Test("HTML contains graph JSON data")
    func containsGraphJSON() throws {
        let html = generateVisualizerHTML(graph: makeSimpleGraph(), machineName: "FolderWatch")
        #expect(html.contains("const GRAPH ="))
        #expect(html.contains("\"machine\""))
        #expect(html.contains("\"nodes\""))
        #expect(html.contains("\"edges\""))
    }
}

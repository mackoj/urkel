import Testing
import Foundation
import UrkelAST
import UrkelParser
@testable import UrkelVisualize
@testable import UrkelCLI

private let printJobSource = """
machine PrintJob

@parallel Processing
  region Rendering
    @states
      init Queued
      state Rendering
      final Rendered

    @transitions
      Queued    -> startRender  -> Rendering
      Rendering -> renderDone   -> Rendered
      Rendering -> renderFailed -> Queued

  region SpoolCheck
    @states
      init Checking
      state Ready
      final Cleared

    @transitions
      Checking -> spoolClear   -> Ready
      Ready    -> after(1s)    -> Cleared
      Checking -> spoolBlocked -> Checking

@states
  init Idle
  state Processing
  state Error
  final Done
  final Failed

@transitions
  Idle -> submit -> Processing
  @on Processing::done -> Done
  Processing -> cancel -> Failed
"""

private let mediaPlayerSource = """
machine MediaPlayer

@states
  init Idle
  state Active @history {
    init Buffering
    state Playing
    state Paused

    Buffering -> bufferReady -> Playing
    Playing   -> pause       -> Paused
    Paused    -> resume      -> Playing
  }
  final Stopped

@transitions
  Idle   -> load -> Active
  Active -> stop -> Stopped
"""


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

    // MARK: - GraphJSON regions (parallel machines)

    @Test("GraphJSON regions populated for parallel machine")
    func parallelRegionsInGraphJSON() throws {
        let file = try UrkelParser.parse(printJobSource)
        let graph = GraphJSON.from(file)
        #expect(!graph.regions.isEmpty)
        #expect(graph.regions.contains { $0.parallelState == "Processing" })
        let rendering = graph.regions.first { $0.regionName == "Rendering" }
        #expect(rendering != nil)
        #expect(rendering?.nodes.contains { $0.id == "Queued" } == true)
        #expect(rendering?.edges.contains { $0.label == "startRender" } == true)
        let spoolCheck = graph.regions.first { $0.regionName == "SpoolCheck" }
        #expect(spoolCheck != nil)
        #expect(spoolCheck?.nodes.contains { $0.id == "Checking" } == true)
    }

    @Test("GraphJSON outer nodes exclude compound/region children")
    func outerNodesExcludeRegionChildren() throws {
        let file = try UrkelParser.parse(printJobSource)
        let graph = GraphJSON.from(file)
        // Queued, Rendering, Rendered, Checking, Ready, Cleared are region children
        let outerIds = graph.nodes.map(\.id)
        #expect(!outerIds.contains("Queued"))
        #expect(!outerIds.contains("Checking"))
        // Outer states like Idle, Processing, Done, Failed should be present
        #expect(outerIds.contains("Idle"))
        #expect(outerIds.contains("Processing"))
        #expect(outerIds.contains("Done"))
    }

    // MARK: - GraphJSON compounds

    @Test("GraphJSON compounds populated for compound-state machine")
    func compoundsInGraphJSON() throws {
        let file = try UrkelParser.parse(mediaPlayerSource)
        let graph = GraphJSON.from(file)
        #expect(!graph.compounds.isEmpty)
        let active = graph.compounds.first { $0.parentState == "Active" }
        #expect(active != nil)
        #expect(active?.hasHistory == true)
        #expect(active?.childNodes.contains { $0.id == "Buffering" } == true)
        #expect(active?.childNodes.contains { $0.id == "Playing" } == true)
        #expect(active?.childNodes.contains { $0.id == "Paused" } == true)
        #expect(active?.innerEdges.contains { $0.label == "bufferReady" } == true)
    }

    @Test("GraphJSON compound outer node present, children absent from outer nodes")
    func compoundOuterNodePresentChildrenAbsent() throws {
        let file = try UrkelParser.parse(mediaPlayerSource)
        let graph = GraphJSON.from(file)
        let outerIds = graph.nodes.map(\.id)
        #expect(outerIds.contains("Active"))   // container present
        #expect(!outerIds.contains("Buffering")) // children not in outer list
        #expect(!outerIds.contains("Playing"))
        #expect(!outerIds.contains("Paused"))
    }

    // MARK: - HTML swimlane markup

    @Test("HTML contains swimlane markup for parallel machine")
    func htmlContainsSwimlane() throws {
        let file = try UrkelParser.parse(printJobSource)
        let graph = GraphJSON.from(file)
        let html = generateVisualizerHTML(graph: graph, machineName: "PrintJob")
        // The JS should reference regionsByParallel (container data)
        #expect(html.contains("regionsByParallel"))
        #expect(html.contains("\"regions\""))
        #expect(html.contains("\"parallelState\""))
        #expect(html.contains("\"Processing\""))
        #expect(html.contains("\"Rendering\""))
        #expect(html.contains("\"SpoolCheck\""))
    }

    @Test("HTML contains compound markup for compound-state machine")
    func htmlContainsCompound() throws {
        let file = try UrkelParser.parse(mediaPlayerSource)
        let graph = GraphJSON.from(file)
        let html = generateVisualizerHTML(graph: graph, machineName: "MediaPlayer")
        #expect(html.contains("compoundByState"))
        #expect(html.contains("\"compounds\""))
        #expect(html.contains("\"parentState\""))
        #expect(html.contains("\"Active\""))
        #expect(html.contains("hasHistory"))
    }

    @Test("HTML backward compat: simple graph unchanged structure")
    func htmlSimpleGraphBackwardCompat() throws {
        let html = generateVisualizerHTML(graph: makeSimpleGraph(), machineName: "FolderWatch")
        #expect(html.contains("\"regions\":[]"))
        #expect(html.contains("\"compounds\":[]"))
    }
}

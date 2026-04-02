import Foundation
import UrkelVisualize
import UrkelEmitterMustache

/// Renders a ``GraphJSON`` to a self-contained HTML visualizer page.
///
/// The page template lives at
/// `Sources/UrkelEmitterMustache/Templates/visualizer.html.mustache`
/// and is rendered via ``MustacheEmitter`` so the layout can be edited
/// without recompiling the CLI.
func generateVisualizerHTML(graph: GraphJSON, machineName: String) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(graph)
    let graphJSON = String(data: data, encoding: .utf8)!
    let context: [String: Any] = [
        "machineName": machineName,
        "graphJSON": graphJSON,
    ]
    return try MustacheEmitter().render(context: context, language: "visualizer.html")
}

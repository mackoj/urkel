import Benchmark
import Foundation
import UrkelAST
import UrkelEmitterSwift
import UrkelParser
import UrkelValidation

/// The showcase machines in `Examples/Showcase`, read once so there is one copy.
enum Fixtures {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Examples/Showcase/Sources/Showcase")

    static let sources: [String] = {
        let names = try! FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".urkel") }.sorted()
        precondition(names.count > 20, "Expected the showcase machines in \(directory.path)")
        return names.map { try! String(contentsOf: directory.appendingPathComponent($0), encoding: .utf8) }
    }()

    static let files: [UrkelFile] = sources.map { try! UrkelParser.parse($0) }

    /// A machine far larger than the showcase ones, to show costs that grow with size: `states` states in a chain,
    /// each with a typed event to the next, a way back, a guarded branch, a shared failure event and an action,
    /// plus state-carried data, entry and exit hooks, timers, a wildcard and a compound state.
    static func largeSource(states: Int = 200) -> String {
        var lines = [
            "## A synthetic machine for benchmarks.",
            "machine Large: LargeContext",
            "",
            "@states",
            "  init Idle",
        ]
        for i in 0..<states {
            lines.append(i % 5 == 0 ? "  state(count: Int, label: String) S\(i)" : "  state S\(i)")
        }
        lines += [
            "  state Session {",
            "    init Active",
            "    state Paused",
            "    Active -> pause -> Paused",
            "    Paused -> resume -> Active",
            "  }",
            "  final(reason: String) Failed",
            "  final Done",
            "",
        ]
        for i in stride(from: 0, to: states, by: 10) {
            lines.append("@entry S\(i) / logEntry, startSpinner")
            lines.append("@exit S\(i) / stopSpinner")
        }
        lines += ["", "@transitions", "  Idle -> start -> S0"]
        for i in 0..<states {
            let next = i + 1 < states ? "S\(i + 1)" : "Session"
            let carried = (i + 1) % 5 == 0 && i + 1 < states
            lines.append("  ## Moves S\(i) forward.")
            lines.append(
                carried
                    ? "  S\(i) -> step\(i)(count: Int, label: String) -> \(next) / track"
                    : "  S\(i) -> step\(i)(value: Int) -> \(next) / track")
            if i > 0 { lines.append("  S\(i) -> back -> S\(i - 1)") }
            lines.append("  S\(i) -> check [isReady] -> \(next)")
            lines.append("  S\(i) -> check [else] -> Failed")
            lines.append("  S\(i) -> fail(reason: String) -> Failed")
            if i % 20 == 0 { lines.append("  S\(i) -> after(5s) -> Failed") }
        }
        lines += [
            "  Session -> finish -> Done",
            "  * -> cancel -> Done",
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    static let large = largeSource()
    static let largeFile = try! UrkelParser.parse(large)
}

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.wallClock, .cpuTotal, .mallocCountTotal, .peakMemoryResident, .retainCount],
        // Exact counts and microseconds, so a change of a few percent shows up in a comparison.
        timeUnits: .microseconds,
        units: [.mallocCountTotal: .count, .retainCount: .count],
        maxDuration: .seconds(2),
        maxIterations: 1_000
    )

    // MARK: Parsing

    Benchmark("Parse, showcase") { benchmark in
        for source in Fixtures.sources { blackHole(try UrkelParser.parse(source)) }
    }

    Benchmark("Parse, large") { benchmark in
        blackHole(try UrkelParser.parse(Fixtures.large))
    }

    // MARK: Validation

    Benchmark("Validate, showcase") { benchmark in
        for file in Fixtures.files { blackHole(UrkelValidator.validate(file)) }
    }

    Benchmark("Validate, large") { benchmark in
        blackHole(UrkelValidator.validate(Fixtures.largeFile))
    }

    // MARK: Swift emission

    Benchmark("Emit Swift, showcase") { benchmark in
        for file in Fixtures.files { blackHole(try SwiftSyntaxEmitter().emit(file: file)) }
    }

    Benchmark("Emit Swift, large") { benchmark in
        blackHole(try SwiftSyntaxEmitter().emit(file: Fixtures.largeFile))
    }

    // MARK: The whole pipeline

    Benchmark("Compile, showcase") { benchmark in
        for source in Fixtures.sources {
            let file = try UrkelParser.parse(source)
            blackHole(UrkelValidator.validate(file))
            blackHole(try SwiftSyntaxEmitter().emit(file: file))
        }
    }

    Benchmark("Format, showcase") { benchmark in
        let parser = UrkelParser()
        for source in Fixtures.sources { blackHole(parser.format(source)) }
    }
}

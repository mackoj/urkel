// swift-tools-version: 6.1
import PackageDescription

// Urkel's benchmarks, on ordo-one/package-benchmark (https://www.swift.org/blog/benchmarks/). A separate package so
// the benchmark dependency never reaches Urkel's clients. Run from the repository root:
// `swift package --package-path Benchmarks benchmark`.
let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "urkel", path: ".."),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.38.0"),
    ],
    targets: [
        .executableTarget(
            name: "UrkelBenchmarks",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "UrkelAST", package: "urkel"),
                .product(name: "UrkelParser", package: "urkel"),
                .product(name: "UrkelValidation", package: "urkel"),
                .product(name: "UrkelEmitterSwift", package: "urkel"),
            ],
            path: "Benchmarks/UrkelBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        // Reads two `benchmark --format markdown` outputs and prints each benchmark's p50 before and after.
        .executableTarget(name: "p50", path: "Tools/P50"),
        // Reads an exported Time Profiler table and prints the hottest functions (scripts/profile.sh).
        .executableTarget(name: "hotspots", path: "Tools/Hotspots"),
    ]
)

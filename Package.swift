// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Urkel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Urkel", targets: ["Urkel"]),
        .executable(name: "urkel", targets: ["UrkelCLI"]),
        .executable(name: "urkel-lsp", targets: ["UrkelLSP"]),
        .plugin(name: "UrkelPlugin", targets: ["UrkelPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.12.0")
    ],
    targets: [
        .target(
            name: "Urkel",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "Mustache", package: "swift-mustache"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            path: "Sources/Urkel",
            resources: [
                .process("Templates")
            ]
        ),
        .executableTarget(
            name: "UrkelCLI",
            dependencies: [
                "Urkel",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/UrkelCLI"
        ),
        .executableTarget(
            name: "UrkelLSP",
            dependencies: ["Urkel"],
            path: "Sources/UrkelLSP"
        ),
        .plugin(
            name: "UrkelPlugin",
            capability: .buildTool(),
            dependencies: ["UrkelCLI"]
        ),
        .testTarget(
            name: "UrkelTests",
            dependencies: [
                "Urkel",
                "UrkelCLI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing")
            ]
        )
    ]
)

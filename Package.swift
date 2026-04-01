// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Urkel",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Urkel", targets: ["Urkel"]),
        .library(name: "UrkelVisualize", targets: ["UrkelVisualize"]),
        .executable(name: "UrkelCLI", targets: ["UrkelCLI"]),
//        .executable(name: "urkel-lsp", targets: ["UrkelLSP"]),
        .plugin(name: "UrkelPlugin", targets: ["UrkelPlugin"]),
        .plugin(name: "UrkelGenerate", targets: ["UrkelGenerate"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0"),
        .package(url: "https://github.com/hummingbird-project/swift-mustache", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.12.0"),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.14.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "601.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "Urkel",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "Mustache", package: "swift-mustache"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
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
                "UrkelVisualize",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/UrkelCLI"
        ),
        .target(
            name: "UrkelVisualize",
            dependencies: ["Urkel"],
            path: "Sources/UrkelVisualize"
        ),
        .executableTarget(
            name: "UrkelLSP",
            dependencies: [
                "Urkel",
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol")
            ],
            path: "Sources/UrkelLSP"
        ),
        .plugin(
            name: "UrkelPlugin",
            capability: .buildTool(),
            dependencies: ["UrkelCLI"]
        ),
        .plugin(
            name: "UrkelGenerate",
            capability: .command(
                intent: .custom(
                    verb: "urkel-generate",
                    description: "Generate checked-in Urkel Swift files from .urkel sources"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "Generate checked-in Swift files from .urkel sources."
                    )
                ]
            ),
            dependencies: ["UrkelCLI"],
            path: "Plugins/UrkelGenerate"
        ),
        .testTarget(
            name: "UrkelTests",
            dependencies: [
                "Urkel",
                "UrkelVisualize",
                "UrkelCLI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing")
            ]
        )
    ]
)

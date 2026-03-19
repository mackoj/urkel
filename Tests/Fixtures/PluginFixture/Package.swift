// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginFixture",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../../"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Fixture",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            plugins: [
                .plugin(name: "UrkelPlugin", package: "Urkel")
            ]
        )
    ]
)

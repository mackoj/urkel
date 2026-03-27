// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Showcase",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "Showcase", targets: ["Showcase"]),
    ],
    dependencies: [
        // Local Urkel checkout — the parent of the Examples/ folder.
        .package(path: "../../"),
    ],
    targets: [
        .target(
            name: "Showcase",
            dependencies: [],
            plugins: [
                .plugin(name: "UrkelPlugin", package: "Urkel"),
            ]
        ),
    ]
)

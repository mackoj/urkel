// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UrkelBird",
    platforms: [
        .iOS(.v13),
        .macOS(.v13),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "UrkelBird",
            targets: ["UrkelBird"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0")
    ],
    targets: [
        .target(
            name: "UrkelBird",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ],
            exclude: [
                "urkelbird.urkel",
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "UrkelBirdTests",
            dependencies: ["UrkelBird"]
        )
    ]
)

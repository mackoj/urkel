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
        .executable(
            name: "UrkelBirdDemo",
            targets: ["UrkelBirdDemo"]
        )
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
                ".DS_Store"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .executableTarget(
            name: "UrkelBirdDemo",
            dependencies: ["UrkelBird"]
        ),
        .testTarget(
            name: "UrkelBirdTests",
            dependencies: ["UrkelBird"]
        )
    ]
)

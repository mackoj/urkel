// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SmartWatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SmartWatch",
            targets: ["SmartWatch"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
        .package(path: "../../"),
    ],
    targets: [
        .target(
            name: "SmartWatch",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "SmartWatchTests",
            dependencies: ["SmartWatch"]
        )
    ]
)

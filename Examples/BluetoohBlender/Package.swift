// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BluetoohBlender",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BluetoohBlender",
            targets: ["BluetoohBlender"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0")
    ],
    targets: [
        .target(
            name: "BluetoohBlender",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "BluetoohBlenderTests",
            dependencies: ["BluetoohBlender"]
        )
    ]
)

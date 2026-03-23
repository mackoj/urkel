// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BluetoohScale",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BluetoohScale",
            targets: ["BluetoohScale"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
        .package(path: "../../"),
    ],
    targets: [
        .target(
            name: "BluetoohScale",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .testTarget(
            name: "BluetoohScaleTests",
            dependencies: ["BluetoohScale"]
        )
    ]
)

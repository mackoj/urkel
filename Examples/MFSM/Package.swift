// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MultipleFSM",
  platforms: [
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "MultipleFSM",
      targets: ["MultipleFSM"]
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies.git",
      from: "1.8.1"
    ),
    .package(path: "../../"),
  ],
  targets: [
    .target(
      name: "MultipleFSM",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .testTarget(
      name: "MultipleFSMTests",
      dependencies: ["MultipleFSM"]
    ),
  ]
)

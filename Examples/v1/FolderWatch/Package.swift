// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "FolderWatch",
  platforms: [
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "FolderWatch",
      targets: ["FolderWatch"]
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-async-algorithms.git",
      from: "1.0.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies.git",
      from: "1.8.1"
    ),
    .package(
      url: "https://github.com/Frizlab/FSEventsWrapper.git",
      from: "2.1.0"
    ),
    .package(path: "../../"),
  ],
    targets: [
    .target(
      name: "FolderWatch",
      dependencies: [
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "FSEventsWrapper", package: "FSEventsWrapper"),
      ]
    ),
    .testTarget(
      name: "FolderWatchTests",
      dependencies: ["FolderWatch"]
    ),
  ]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "ReaderKitConsumers",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(name: "ReaderKit", path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "ReaderKitConsumer",
      dependencies: [.product(name: "ReaderKit", package: "ReaderKit")]
    ),
    .executableTarget(
      name: "ReadabilityConsumer",
      dependencies: [.product(name: "Readability", package: "ReaderKit")]
    ),
    .executableTarget(
      name: "RichTextConsumer",
      dependencies: [.product(name: "RichText", package: "ReaderKit")]
    )
  ]
)

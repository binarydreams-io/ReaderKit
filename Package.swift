// swift-tools-version: 6.2
// Copyright 2026 Binary Dreams, LLC.
// SPDX-License-Identifier: Apache-2.0

import PackageDescription

let upcoming: [SwiftSetting] = [
  .enableUpcomingFeature("InferIsolatedConformances"),
  .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
  name: "ReaderKit",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v14)
  ],
  products: [
    .library(name: "Readability", targets: ["Readability"]),
    .library(name: "RichText", targets: ["RichText"]),
    .library(name: "ReaderKit", targets: ["ReaderKit"])
  ],
  dependencies: [
    .package(url: "https://github.com/scinfu/SwiftSoup", .upToNextMajor(from: "2.11.2")),
    .package(url: "https://github.com/kean/Nuke", .upToNextMajor(from: "13.0.4"))
  ],
  targets: [
    .target(
      name: "Readability",
      dependencies: [
        .product(name: "SwiftSoup", package: "SwiftSoup")
      ],
      path: "Sources/Readability",
      swiftSettings: upcoming
    ),
    .target(
      name: "RichText",
      dependencies: [
        .product(name: "SwiftSoup", package: "SwiftSoup"),
        .product(name: "NukeUI", package: "Nuke")
      ],
      path: "Sources/RichText",
      swiftSettings: upcoming
    ),
    .target(
      name: "ReaderKit",
      dependencies: ["Readability", "RichText"],
      path: "Sources/ReaderKit",
      resources: [
        .process("Resources")
      ],
      swiftSettings: upcoming
    ),
    .testTarget(
      name: "ReadabilityTests",
      dependencies: [
        "Readability",
        .product(name: "SwiftSoup", package: "SwiftSoup")
      ],
      path: "Tests/ReadabilityTests",
      resources: [
        .copy("Resources/test-pages")
      ]
    ),
    .testTarget(
      name: "RichTextTests",
      dependencies: [
        "RichText",
        .product(name: "SwiftSoup", package: "SwiftSoup")
      ],
      path: "Tests/RichTextTests"
    ),
    .testTarget(
      name: "ReaderKitTests",
      dependencies: [
        "ReaderKit"
      ],
      path: "Tests/ReaderKitTests"
    )
  ]
)

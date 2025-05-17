// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "SwiftClaudeAppPackage",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
    .visionOS(.v2),
  ],
  products: [
    .library(
      name: "SwiftClaudeAppPackage",
      targets: ["App"]
    )
  ],
  dependencies: [
    .package(name: "SwiftClaude", path: "../..")
  ],
  targets: [
    .target(
      name: "App",
      dependencies: [
        "HaikuGenerator",
      ]
    ),
    .target(
      name: "HaikuGenerator",
      dependencies: [
        "SwiftClaude"
      ],
      path: "Sources/Haiku Generator",
      swiftSettings: [
        /// Uncomment this line to disable tool use
        // .define("TOOL_USE_DISABLED")
      ]
    ),

    .testTarget(
      name: "SwiftClaudeAppPackageTests",
      dependencies: [
        "App"
      ],
      path: "Tests/App Tests"
    ),
  ]
)

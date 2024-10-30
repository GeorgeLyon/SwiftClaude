// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "ExamplesPackage",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
    .visionOS(.v2),
  ],
  products: [
    .library(
      name: "ExamplesPackage",
      targets: [
        "HaikuGeneratorExample",
        "ComputerUseExample",
      ]
    )
  ],
  dependencies: [
    .package(path: "../..")
  ],
  targets: [
    .target(
      name: "HaikuGeneratorExample",
      dependencies: [
        "SwiftClaude"
      ],
      path: "Sources/Haiku Generator"
    ),
    .target(
      name: "ComputerUseExample",
      dependencies: [
        "SwiftClaude"
      ],
      path: "Sources/Computer Use",
      resources: [
        .process("Screenshot.png")
      ]
    ),
  ]
)

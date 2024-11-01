// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "SwiftClaude",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
    .visionOS(.v2),
  ],
  products: [
    .library(
      name: "SwiftClaude",
      targets: ["Claude"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "ClaudeClient",
      dependencies: [
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
      ],
      path: "Sources/Client",
      swiftSettings: .claude
    ),
    .testTarget(
      name: "ClaudeClientTests",
      dependencies: ["ClaudeClient"],
      path: "Tests/Claude Client Tests"
    ),

    .target(
      name: "ClaudeMessagesEndpoint",
      dependencies: [
        "ClaudeClient"
      ],
      path: "Sources/Messages Endpoint",
      swiftSettings: .claude
    ),

    .target(
      name: "Claude",
      dependencies: [
        "ClaudeMessagesEndpoint",
        .target(name: "ClaudeToolInput", condition: .when(platforms: .supportToolInput)),
        .target(name: "ClaudeMacros", condition: .when(platforms: .supportToolInput)),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      ],
      swiftSettings: .claude
    ),
    .testTarget(
      name: "ClaudeTests",
      dependencies: ["Claude"],
      path: "Tests/Claude Tests"
    ),

    .target(
      name: "ClaudeToolInput",
      path: "Sources/Tool Input"
    ),
    .testTarget(
      name: "ClaudeToolInputTests",
      dependencies: ["ClaudeToolInput"],
      path: "Tests/Tool Input Tests"
    ),

    .macro(
      name: "ClaudeMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      path: "Sources/Macros"
    ),
  ]
)

extension Array where Element == Platform {
  fileprivate static var supportToolInput: [Platform] {
    [.iOS, .macOS, .macCatalyst, .visionOS, .tvOS, .watchOS]
  }
}

extension Array where Element == SwiftSetting {
  fileprivate static let claude: [SwiftSetting] = [
    .enableUpcomingFeature("InternalImportsByDefault")
  ]
}

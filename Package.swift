// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "SwiftClaude",
  platforms: [
    .macOS("15.0"),
    .iOS("18.0"),
    .watchOS("11.0"),
    .tvOS("18.0"),
    .visionOS("2.0"),
  ],
  products: [
    // .library(
    //   name: "SwiftClaude",
    //   targets: ["Claude"]
    // ),

    /// Temporary
    .library(
      name: "SchemaCoding",
      targets: ["SchemaCoding"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
  ],
  targets: [
    // .target(
    //   name: "ClaudeClient",
    //   dependencies: [
    //     "Tool",
    //     .product(name: "HTTPTypes", package: "swift-http-types"),
    //     .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
    //   ],
    //   path: "Sources/Client",
    //   swiftSettings: .claude
    // ),
    // .testTarget(
    //   name: "ClaudeClientTests",
    //   dependencies: ["ClaudeClient"],
    //   path: "Tests/Client Tests"
    // ),

    // .target(
    //   name: "ClaudeMessagesEndpoint",
    //   dependencies: [
    //     "ClaudeClient"
    //   ],
    //   path: "Sources/Messages Endpoint",
    //   swiftSettings: .claude
    // ),

    // .target(
    //   name: "Claude",
    //   dependencies: [
    //     "ClaudeMessagesEndpoint",
    //     .target(name: "Tool", condition: .when(platforms: .supportToolInput)),
    //     .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
    //   ],
    //   swiftSettings: .claude
    // ),
    // .testTarget(
    //   name: "ClaudeTests",
    //   dependencies: ["Claude"],
    //   path: "Tests/Claude Tests"
    // ),

    .target(
      name: "Tool",
      dependencies: [
        "Macros",
        "SchemaCoding",
      ],
      swiftSettings: .projectDefaults,
    ),
    .testTarget(
      name: "ToolTests",
      dependencies: ["Tool"],
      path: "Tests/Tool Tests"
    ),

    // MARK: - Schema Coding

    .target(
      name: "SchemaCoding",
      dependencies: [
        "JSONSupport",
        "Macros",
      ],
      path: "Sources/Schema Coding",
      swiftSettings: .projectDefaults
    ),
    .testTarget(
      name: "SchemaCodingTests",
      dependencies: ["SchemaCoding"],
      path: "Tests/Schema Coding Tests"
    ),

    // MARK: - Macros Support

    /// Splitting macros into libraries causes a linker issue on macOS, so we put everything in one target
    .macro(
      name: "Macros",
      dependencies: [
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      path: "Sources/Macros",
      swiftSettings: .projectDefaults
    ),
    .testTarget(
      name: "MacrosTests",
      dependencies: [
        "Macros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      path: "Tests/Macros Tests"
    ),

    // MARK: - JSON Support

    .target(
      name: "JSONSupport",
      dependencies: [],
      path: "Sources/JSON Support",
      swiftSettings: .projectDefaults
    ),
    .testTarget(
      name: "JSONSupportTests",
      dependencies: [
        "JSONSupport"
      ],
      path: "Tests/JSON Support Tests"
    ),
  ]
)

extension Array where Element == SwiftSetting {
  fileprivate static let projectDefaults: [SwiftSetting] = [
    .enableUpcomingFeature("InternalImportsByDefault")
  ]
}

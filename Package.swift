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
    .library(
      name: "SwiftClaude",
      targets: ["ClaudeAPI"]
    ),
    .library(
      name: "MCPServer",
      targets: ["MCPServer"]
    ),
    .executable(
      name: "MCPServerExample",
      targets: ["MCPServerExample"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),

    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
  ],
  targets: [
    .target(
      name: "ClaudeClient",
      dependencies: [
        "Tool",
        "ClaudeCommon",
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "HTTPTypesFoundation", package: "swift-http-types"),
      ],
      path: "Sources/Client",
      swiftSettings: .projectDefault
    ),
    .testTarget(
      name: "ClaudeClientTests",
      dependencies: ["ClaudeClient"],
      path: "Tests/Client Tests"
    ),

    .target(
      name: "ClaudeMessagesEndpoint",
      dependencies: [
        "ClaudeClient",
        "ClaudeCommon",
      ],
      path: "Sources/Messages Endpoint",
      swiftSettings: .projectDefault
    ),

    .target(
      name: "ClaudeAPI",
      dependencies: [
        "ClaudeMessagesEndpoint",
        .target(name: "Tool", condition: .when(platforms: .supportToolInput)),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      ],
      path: "Sources/Claude API",
      swiftSettings: .projectDefault
    ),
    .testTarget(
      name: "ClaudeTests",
      dependencies: ["ClaudeAPI"],
      path: "Tests/Claude Tests"
    ),

    .target(
      name: "MCPServer",
      dependencies: [
        "Tool",
        .product(name: "MCP", package: "swift-sdk"),
      ],
      path: "Sources/MCP Server",
      swiftSettings: .projectDefault
    ),
    .executableTarget(
      name: "MCPServerExample",
      dependencies: ["MCPServer"],
      path: "Examples/MCP Server",
      swiftSettings: .projectDefault
    ),

    .target(
      name: "Tool",
      dependencies: [
        "ToolMacros",
        "ClaudeCommon",
      ],
      swiftSettings: .projectDefault
    ),
    .testTarget(
      name: "ToolTests",
      dependencies: ["Tool"],
      path: "Tests/Tool Tests"
    ),

    .macro(
      name: "ToolMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
      ],
      path: "Sources/Tool Macros"
    ),
    .testTarget(
      name: "ToolMacrosTests",
      dependencies: [
        "ToolMacros",
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      path: "Tests/Tool Macros Tests"
    ),

    .target(
      name: "ClaudeCommon",
      path: "Sources/Common"
    ),
  ]
)

extension Array where Element == Platform {
  fileprivate static var supportToolInput: [Platform] {
    [.iOS, .macOS, .macCatalyst, .visionOS, .tvOS, .watchOS, .linux]
  }
}

extension Array where Element == SwiftSetting {
  fileprivate static let projectDefault: [SwiftSetting] = [
    .enableUpcomingFeature("InternalImportsByDefault")
  ]
}

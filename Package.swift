// swift-tools-version: 6.0

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
  name: "SwiftClaude",
  platforms: [
    .macOS("26.0"),
    .iOS("26.0"),
    .watchOS("26.0"),
    .tvOS("26.0"),
    .visionOS("26.0"),
  ],
  products: [
    .library(
      name: "SwiftClaude",
      targets: ["StructuredCoding"]
    )
  ],
  dependencies: [
    // .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    // .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    .package(url: "https://github.com/apple/swift-collections.git", branch: "main"),
  ],
  targets: [
    .target(
      name: "StructuredCoding",
      dependencies: [
        "JavaScriptObjectNotation",
        "StructuredCodingMacros",
        .product(name: "BasicContainers", package: "swift-collections"),
      ],
      path: "Sources/Structured Coding",
      swiftSettings: .projectDefaults
    ),
    // .target(
    //   name: "SchemaCodingTestSupport",
    //   dependencies: [
    //     "SchemaCoding"
    //   ],
    //   path: "Sources/Schema Coding Test Support",
    //   swiftSettings: .projectDefaults
    // ),
    .testTarget(
      name: "StructuredCodingTests",
      dependencies: [
        "StructuredCoding",
        "JavaScriptObjectNotation",
      ],
      path: "Tests/Structured Coding Tests",
      swiftSettings: .projectDefaults
    ),

    .macro(
      name: "StructuredCodingMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      path: "Sources/Structured Coding Macros",
      exclude: ["Support/Convert To Snake Case/LICENSE.md"],
      swiftSettings: .projectDefaults
    ),
    .testTarget(
      name: "StructuredCodingMacrosTests",
      dependencies: [
        "StructuredCodingMacros",
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
      ],
      path: "Tests/Structured Coding Macros Tests",
      swiftSettings: .projectDefaults
    ),

    .target(
      name: "JavaScriptObjectNotation",
      dependencies: [
        .product(name: "DequeModule", package: "swift-collections")
      ],
      path: "Sources/JavaScript Object Notation",
      swiftSettings: .projectDefaults
    ),
    .testTarget(
      name: "JavaScriptObjectNotationTests",
      dependencies: [
        "JavaScriptObjectNotation"
      ],
      path: "Tests/JavaScript Object Notation Tests",
      swiftSettings: .projectDefaults
    ),
  ]
)

extension Array where Element == SwiftSetting {
  fileprivate static let projectDefaults: [SwiftSetting] = {
    var settings: [SwiftSetting] = [
      /// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md
      .enableUpcomingFeature("NonisolatedNonsendingByDefault"),

      /// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
      .enableUpcomingFeature("InternalImportsByDefault"),

      /// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
      .enableUpcomingFeature("MemberImportVisibility"),

      /// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0481-weak-let.md
      .enableUpcomingFeature("ImmutableWeakCaptures"),

      /// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md
      .enableUpcomingFeature("InferIsolatedConformances"),

      /// For `~Escapable` types
      .enableExperimentalFeature("SuppressedAssociatedTypes"),
      .enableExperimentalFeature("LifetimeDependence"),
      .enableExperimentalFeature("Lifetimes"),

      /// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0519-borrow-and-inout-types.md
      // .enableExperimentalFeature("BorrowInout")
    ]
    if enableTestingInRelease {
      /// Allow testing release builds
      settings.append(.unsafeFlags(["-enable-testing"], .when(configuration: .release)))
    }
    return settings
  }()

  private static let enableTestingInRelease =
    ProcessInfo.processInfo.environment["SWIFTCLAUDE_ENABLE_TESTING_IN_RELEASE"] == "true"
}

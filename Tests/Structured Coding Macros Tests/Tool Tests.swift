import SwiftDiagnostics
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Verifies that `@StructuredTool` gathers a type's `@StructuredAction`
/// functions — pure markers — into a nested `Definition` container storing
/// the tool's name (a literal: the attribute's `name:`, or the type's name),
/// its description (`nil` when the attribute provides none), and an
/// `actions` value holding one inline `StructuredAction` per function (its
/// concrete type inferred from the initializer, never spelled), plus a
/// computed `static var definition`; and diagnoses the shapes a tool cannot
/// represent.
@Suite
struct StructuredToolTests {

  @Test
  func gathersActionsIntoNestedDefinition() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
        func ping() {
        }

        @StructuredAction
        func pong() {
        }
      }
      """,
#"""
      struct S {
        func ping() {
        }
        func pong() {
        }

        struct Definition: StructuredCoding.StructuredToolDefinitionProtocol {
          typealias Callee = S
          let name = "S"
          let description: String? = nil
          let actions = StructuredCoding.StructuredAction.build {
            StructuredCoding.StructuredAction(
              name: "ping",
              failure: Never.self,
              invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredEmptyObject in
                callee.ping()
                return StructuredCoding.StructuredEmptyObject()
              }
            )
            StructuredCoding.StructuredAction(
              name: "pong",
              failure: Never.self,
              invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredEmptyObject in
                callee.pong()
                return StructuredCoding.StructuredEmptyObject()
              }
            )
          }
        }

        static var definition: Definition {
          Definition()
        }
      }

      extension S: StructuredCoding.StructuredToolProtocol {
      }
      """#
    )
  }

  @Test
  func nameAndDescriptionArgumentsBecomeStoredProperties() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool(name: "calc", description: "A tool")
      public struct S {
        @StructuredAction
        public func ping() {
        }
      }
      """,
#"""
      public struct S {
        public func ping() {
        }

        public struct Definition: StructuredCoding.StructuredToolDefinitionProtocol {
          public typealias Callee = S
          public let name = "calc"
          public let description: String? = "A tool"
          public let actions = StructuredCoding.StructuredAction.build {
            StructuredCoding.StructuredAction(
              name: "ping",
              failure: Never.self,
              invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredEmptyObject in
                callee.ping()
                return StructuredCoding.StructuredEmptyObject()
              }
            )
          }
        }

        public static var definition: Definition {
          Definition()
        }
      }

      extension S: StructuredCoding.StructuredToolProtocol {
      }
      """#
    )
  }

  // MARK: - Diagnostics

  /// A tool with nothing to dispatch to is a mistake, not an empty tool.
  @Test
  func rejectsToolWithoutActions() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        func f() {
        }
      }
      """,
      """
      struct S {
        func f() {
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StructuredTool requires at least one @StructuredAction function",
          line: 1, column: 1)
      ]
    )
  }

  /// Tools dispatch actions by base name, so overloads cannot both join.
  @Test
  func rejectsDuplicateActionNames() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
        func over(_ x: Int) -> Int {
          x
        }

        @StructuredAction
        func over(_ x: String) -> String {
          x
        }
      }
      """,
      """
      struct S {
        func over(_ x: Int) -> Int {
          x
        }
        func over(_ x: String) -> String {
          x
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "Duplicate action name `over`; a tool's actions must have unique names",
          line: 9, column: 8)
      ]
    )
  }

  /// A static action has no callee to join a `Callee == S` tuple.
  @Test
  func rejectsStaticActions() {
    assertStructuredCodableExpansion(
      """
      @StructuredTool
      struct S {
        @StructuredAction
        static func make() {
        }
      }
      """,
      """
      struct S {
        static func make() {
        }
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message: "static @StructuredAction functions are not supported in a @StructuredTool",
          line: 4, column: 15)
      ]
    )
  }

}

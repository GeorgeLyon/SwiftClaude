import SwiftDiagnostics
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Verifies that `@StructuredTool` gathers a type's `@StructuredAction`
/// functions — pure markers — into a single `definition` member holding one
/// inline `StructuredAction` per function, and diagnoses the shapes a tool
/// cannot represent.
@Suite
struct StructuredToolTests {

  @Test
  func gathersActionsIntoDefinition() {
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

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              StructuredCoding.StructuredAction(
                name: "ping",
                failure: Never.self,
                invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredEmptyObject in
                  callee.ping()
                  return StructuredCoding.StructuredEmptyObject()
                }
              ),
              StructuredCoding.StructuredAction(
                name: "pong",
                failure: Never.self,
                invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredEmptyObject in
                  callee.pong()
                  return StructuredCoding.StructuredEmptyObject()
                }
              )
            )
          )
        }
      }
      """#
    )
  }

  @Test
  func nameAndDescriptionArgumentsFlowIntoDefinition() {
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

        public static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "calc",
            description: "A tool",
            actions: (
              StructuredCoding.StructuredAction(
                name: "ping",
                failure: Never.self,
                invoke: { (callee: S, _: StructuredCoding.StructuredEmptyObject) -> StructuredCoding.StructuredEmptyObject in
                  callee.ping()
                  return StructuredCoding.StructuredEmptyObject()
                }
              )
            )
          )
        }
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

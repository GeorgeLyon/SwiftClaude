import SwiftDiagnostics
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Verifies that `@StructuredTool` gathers a type's `@StructuredAction`
/// functions into a single `definition` member — pure data gathering, with
/// every generic argument inferred from the sidecar calls — and diagnoses the
/// shapes a tool cannot represent.
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

        static func __structuredAction_ping() -> StructuredCoding.StructuredAction<S, StructuredCoding.StructuredActionSignature<StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, Never>> {
          StructuredCoding.StructuredAction(
            name: "ping",
            invoke: { (callee, _) in
              callee.ping()
              return StructuredCoding.StructuredEmptyObject()
            }
          )
        }
        func pong() {
        }

        static func __structuredAction_pong() -> StructuredCoding.StructuredAction<S, StructuredCoding.StructuredActionSignature<StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, Never>> {
          StructuredCoding.StructuredAction(
            name: "pong",
            invoke: { (callee, _) in
              callee.pong()
              return StructuredCoding.StructuredEmptyObject()
            }
          )
        }

        static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "\(Self.self)",
            actions: (
              __structuredAction_ping(),
              __structuredAction_pong()
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

        public static func __structuredAction_ping() -> StructuredCoding.StructuredAction<S, StructuredCoding.StructuredActionSignature<StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, Never>> {
          StructuredCoding.StructuredAction(
            name: "ping",
            invoke: { (callee, _) in
              callee.ping()
              return StructuredCoding.StructuredEmptyObject()
            }
          )
        }

        public static var definition: some StructuredCoding.StructuredToolDefinitionProtocol<S> {
          StructuredCoding.StructuredToolDefinition(
            name: "calc",
            description: "A tool",
            actions: (
              __structuredAction_ping()
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
      #"""
      struct S {
        func over(_ x: Int) -> Int {
          x
        }

        static func __structuredAction_over(_ x: Int.Type = Int.self) -> StructuredCoding.StructuredAction<S, StructuredCoding.StructuredActionSignature<Int, Int, Int, Never>> {
          StructuredCoding.StructuredAction(
            name: "over",
            invoke: { (callee, input) in
              callee.over(input)
            }
          )
        }
        func over(_ x: String) -> String {
          x
        }

        static func __structuredAction_over(_ x: String.Type = String.self) -> StructuredCoding.StructuredAction<S, StructuredCoding.StructuredActionSignature<String, String, String, Never>> {
          StructuredCoding.StructuredAction(
            name: "over",
            invoke: { (callee, input) in
              callee.over(input)
            }
          )
        }
      }
      """#,
      diagnostics: [
        DiagnosticSpec(
          message: "Duplicate action name `over`; a tool's actions must have unique names",
          line: 9, column: 8)
      ]
    )
  }

  /// A static action's sidecar has `Callee == Void`, which cannot join a
  /// tuple of `Callee == S` actions.
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
      #"""
      struct S {
        static func make() {
        }

        static func __structuredAction_make() -> StructuredCoding.StructuredAction<Void, StructuredCoding.StructuredActionSignature<StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, StructuredCoding.StructuredEmptyObject, Never>> {
          StructuredCoding.StructuredAction(
            name: "make",
            invoke: { (_, _) in
              make()
              return StructuredCoding.StructuredEmptyObject()
            }
          )
        }
      }
      """#,
      diagnostics: [
        DiagnosticSpec(
          message: "static @StructuredAction functions are not supported in a @StructuredTool",
          line: 4, column: 15)
      ]
    )
  }

}

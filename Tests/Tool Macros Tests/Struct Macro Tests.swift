import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import ToolMacros

@Suite("@ToolInput Struct")
private struct StructMacroTests {

  @Test
  func testStructMacro() {

    assertMacroExpansion(
      """
      /// A tool input struct
      @ToolInput
      struct ToolInputStruct {
        let anInteger: Int
        /// An (x, y) coordinate
        let aCoordinate: (Int, Int)
        // Crazy Declaration
        let a, b: Bool, c: String
      }
      """,
      expandedSource: ##"""
        /// A tool input struct
        struct ToolInputStruct {
          let anInteger: Int
          /// An (x, y) coordinate
          let aCoordinate: (Int, Int)
          // Crazy Declaration
          let a, b: Bool, c: String
        }

        extension ToolInputStruct: ToolInput.SchemaCodable {
          static var toolInputSchema: some ToolInput.Schema<Self> {
            ToolInput.structSchema(
              representing: Self.self,
              description: #"""
              A tool input struct
              """#,
              keyedBy: __macro_local_11PropertyKeyfMu_.self,
              properties: (
                (
                  description: nil,
                  keyPath: \Self.anInteger,
                  key: __macro_local_11PropertyKeyfMu_.anInteger,
                  schema: ToolInput.schema(representing: Int.self)
                ),
                (
                  description: #"""
                  An (x, y) coordinate
                  """#,
                  keyPath: \Self.aCoordinate,
                  key: __macro_local_11PropertyKeyfMu_.aCoordinate,
                  schema: ToolInput.schema(representing: (Int, Int).self)
                ),
                (
                  description: #"""
                  Crazy Declaration
                  """#,
                  keyPath: \Self.c,
                  key: __macro_local_11PropertyKeyfMu_.c,
                  schema: ToolInput.schema(representing: String.self)
                ),
                (
                  description: #"""
                  Crazy Declaration
                  """#,
                  keyPath: \Self.b,
                  key: __macro_local_11PropertyKeyfMu_.b,
                  schema: ToolInput.schema(representing: Bool.self)
                ),
                (
                  description: #"""
                  Crazy Declaration
                  """#,
                  keyPath: \Self.a,
                  key: __macro_local_11PropertyKeyfMu_.a,
                  schema: ToolInput.schema(representing: Bool.self)
                )
              ),
              initializer: Self.init(structSchemaDecoder:)
            )
          }
          private enum __macro_local_11PropertyKeyfMu_: Swift.CodingKey {
            case anInteger
            case aCoordinate
            case c
            case b
            case a
          }
          private init(structSchemaDecoder: ToolInput.StructSchemaDecoder<Int, (Int, Int), String, Bool, Bool>) {
            self.anInteger = structSchemaDecoder.propertyValues.0
            self.aCoordinate = structSchemaDecoder.propertyValues.1
            self.c = structSchemaDecoder.propertyValues.2
            self.b = structSchemaDecoder.propertyValues.3
            self.a = structSchemaDecoder.propertyValues.4
          }
        }
        """##,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2),
      failureHandler: {
        Issue.record(
          "\($0.message)",
          sourceLocation: SourceLocation(
            fileID: $0.location.fileID,
            filePath: $0.location.filePath,
            line: $0.location.line,
            column: $0.location.column
          )
        )
      }
    )
  }

  private let macroSpecs = [
    "ToolInput": MacroSpec(type: ToolInputMacro.self)
  ]
}

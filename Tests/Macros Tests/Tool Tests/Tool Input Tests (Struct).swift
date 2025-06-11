import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@ToolInput Struct")
struct ToolInputStructMacroTests {

  @Test
  func testToolInputStructMacro() {

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
      expandedSource: #####"""
        /// A tool input struct
        struct ToolInputStruct {
          let anInteger: Int
          /// An (x, y) coordinate
          let aCoordinate: (Int, Int)
          // Crazy Declaration
          let a, b: Bool, c: String
        }

        extension ToolInputStruct: ToolInput.SchemaCodable {
          static var schema: some ToolInput.Schema<Self> {
            ToolInput.SchemaCodingSupport.structSchema(
              representing: Self.self,
              description: ####"""
              A tool input struct
              """####,
              properties: (
                (
                  description: nil,
                  keyPath: \Self.anInteger,
                  key: "anInteger" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)
                ),
                (
                  description: ####"""
                  An (x, y) coordinate
                  """####,
                  keyPath: \Self.aCoordinate,
                  key: "aCoordinate" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: (Int, Int).self)
                ),
                (
                  description: ####"""
                  Crazy Declaration
                  """####,
                  keyPath: \Self.c,
                  key: "c" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)
                ),
                (
                  description: ####"""
                  Crazy Declaration
                  """####,
                  keyPath: \Self.b,
                  key: "b" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Bool.self)
                ),
                (
                  description: ####"""
                  Crazy Declaration
                  """####,
                  keyPath: \Self.a,
                  key: "a" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Bool.self)
                )
              ),
              initializer: Self.init(structSchemaDecoder:)
            )
          }
          private init(structSchemaDecoder: ToolInput.StructSchemaDecoder<Int, (Int, Int), String, Bool, Bool>) {
            self.anInteger = structSchemaDecoder.propertyValues.0
            self.aCoordinate = structSchemaDecoder.propertyValues.1
            self.c = structSchemaDecoder.propertyValues.2
            self.b = structSchemaDecoder.propertyValues.3
            self.a = structSchemaDecoder.propertyValues.4
          }
        }
        """#####,
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

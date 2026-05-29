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
      @ToolInput(
        description: "A tool input struct"
      )
      struct ToolInputStruct {
        let anInteger: Int
        @SchemaProperty(
          description: "An (x, y) coordinate"
        )
        let aCoordinate: (Int, Int)
        let a, b: Bool, c: String
      }
      """,
      expandedSource: #####"""
        struct ToolInputStruct {
          let anInteger: Int
          let aCoordinate: (Int, Int)
          let a, b: Bool, c: String
        }

        extension ToolInputStruct: ToolInput.SchemaCodable {
          static var schema: some ToolInput.ObjectSchema<Self> & ToolInput.Support.ComplexSchema {
            ToolInput.Support.structSchema(
              description: "A tool input struct",
              properties: {
                ToolInput.Support.structProperty(
                  name: "anInteger",
                  keyPath: \Self.anInteger,
                  schema: ToolInput.Support.schema(
                    representing: Int.self
                  )
                )
                ToolInput.Support.structProperty(
                  name: "aCoordinate",
                  keyPath: \Self.aCoordinate,
                  schema: ToolInput.Support.schema(
                    representing: (Int, Int).self, description: "An (x, y) coordinate"
                  )
                )
                ToolInput.Support.structProperty(
                  name: "a",
                  keyPath: \Self.a,
                  schema: ToolInput.Support.schema(
                    representing: Bool.self
                  )
                )
                ToolInput.Support.structProperty(
                  name: "b",
                  keyPath: \Self.b,
                  schema: ToolInput.Support.schema(
                    representing: Bool.self
                  )
                )
                ToolInput.Support.structProperty(
                  name: "c",
                  keyPath: \Self.c,
                  schema: ToolInput.Support.schema(
                    representing: String.self
                  )
                )
              },
              finishDecoding: Self.init(structDecoder:)
            )
          }
          private init(structDecoder: ToolInput.StructDecoder<Int, (Int, Int), Bool, Bool, String>) {
            self.anInteger = structDecoder.propertyValues.0
            self.aCoordinate = structDecoder.propertyValues.1
            self.a = structDecoder.propertyValues.2
            self.b = structDecoder.propertyValues.3
            self.c = structDecoder.propertyValues.4
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
    "ToolInput": MacroSpec(type: ToolInputMacro.self),
    "SchemaProperty": MacroSpec(type: SchemaPropertyMacro.self),
  ]
}

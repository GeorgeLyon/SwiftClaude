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
        @ToolInputDetails(
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
          static var schema: some ToolInput.ObjectSchema<Self> {
            ToolInput.Support.structSchema(
              description: "A tool input struct",
              propertyName: __macro_local_12PropertyNamefMu_.self,
              properties: {
                ToolInput.Support.structProperty(
                  name: __macro_local_12PropertyNamefMu_.anInteger,
                  schema: ToolInput.Support.schema(
                    representing: Int.self
                  ),
                  keyPath: \Self.anInteger
                )
                ToolInput.Support.structProperty(
                  name: __macro_local_12PropertyNamefMu_.aCoordinate,
                  schema: ToolInput.Support.schema(
                    representing: (Int, Int).self, description: "An (x, y) coordinate",
                  ),
                  keyPath: \Self.aCoordinate
                )
                ToolInput.Support.structProperty(
                  name: __macro_local_12PropertyNamefMu_.a,
                  schema: ToolInput.Support.schema(
                    representing: Bool.self
                  ),
                  keyPath: \Self.a
                )
                ToolInput.Support.structProperty(
                  name: __macro_local_12PropertyNamefMu_.b,
                  schema: ToolInput.Support.schema(
                    representing: Bool.self
                  ),
                  keyPath: \Self.b
                )
                ToolInput.Support.structProperty(
                  name: __macro_local_12PropertyNamefMu_.c,
                  schema: ToolInput.Support.schema(
                    representing: String.self
                  ),
                  keyPath: \Self.c
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
          private enum __macro_local_12PropertyNamefMu_: Swift.String, Swift.CodingKey {
            case anInteger = "anInteger"
            case aCoordinate = "aCoordinate"
            case a = "a"
            case b = "b"
            case c = "c"
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
    "ToolInputDetails": MacroSpec(type: SchemaDetailsMacro.self),
  ]
}

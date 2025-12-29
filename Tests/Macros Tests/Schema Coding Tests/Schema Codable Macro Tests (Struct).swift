import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@SchemaCodable Struct")
private struct SchemaCodableStructTests {

  @Test
  func testSchemaCodableStructMacro() {

    assertMacroExpansion(
      """
      @SchemaCodable(
        description: "Test Struct"
      )
      public struct TestStruct {
        let anInteger: Int

        @SchemaParameters(
          description: "A coordinate"
        )
        let aCoordinate: (Int, Int)

        // Crazy Declaration
        let a, b: Bool, c: String
      }
      """,
      expandedSource: #####"""
        public struct TestStruct {
          let anInteger: Int
          let aCoordinate: (Int, Int)
          // Crazy Declaration
          let a, b: Bool, c: String
        }
        
        extension TestStruct: SchemaCoding.SchemaCodable {
          public static var schema: some SchemaCoding.ObjectSchema<Self> {
            SchemaCoding.Support.structSchema(
              description: "Test Struct",
              properties: {
                SchemaCoding.Support.structProperty(
                  name: "anInteger",
                  schema: SchemaCoding.Support.schema(
                    representing: Int.self
                  ),
                  keyPath: \Self.anInteger
                )
                SchemaCoding.Support.structProperty(
                  name: "aCoordinate",
                  schema: SchemaCoding.Support.schema(
                    representing: (Int, Int).self, description: "A coordinate"
                  ),
                  keyPath: \Self.aCoordinate
                )
                SchemaCoding.Support.structProperty(
                  name: "a",
                  schema: SchemaCoding.Support.schema(
                    representing: Bool.self
                  ),
                  keyPath: \Self.a
                )
                SchemaCoding.Support.structProperty(
                  name: "b",
                  schema: SchemaCoding.Support.schema(
                    representing: Bool.self
                  ),
                  keyPath: \Self.b
                )
                SchemaCoding.Support.structProperty(
                  name: "c",
                  schema: SchemaCoding.Support.schema(
                    representing: String.self
                  ),
                  keyPath: \Self.c
                )
              },
              finishDecoding: Self.init(structDecoder:)
            )
          }
          private init(structDecoder: SchemaCoding.StructDecoder<Int, (Int, Int), Bool, Bool, String>) {
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
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self),
    "SchemaParameters": MacroSpec(type: SchemaParametersMacro.self),
  ]
}

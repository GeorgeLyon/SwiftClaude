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

        @SchemaProperty(
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
          public static var schema: some SchemaCoding.ObjectSchema<Self> & SchemaCoding.Support.ComplexSchema {
            SchemaCoding.Support.structSchema(
              description: "Test Struct",
              properties: {
                SchemaCoding.Support.structProperty(
                  name: "anInteger",
                  keyPath: \Self.anInteger,
                  schema: SchemaCoding.Support.schema(
                    representing: Int.self
                  )
                )
                SchemaCoding.Support.structProperty(
                  name: "aCoordinate",
                  keyPath: \Self.aCoordinate,
                  schema: SchemaCoding.Support.schema(
                    representing: (Int, Int).self, description: "A coordinate"
                  )
                )
                SchemaCoding.Support.structProperty(
                  name: "a",
                  keyPath: \Self.a,
                  schema: SchemaCoding.Support.schema(
                    representing: Bool.self
                  )
                )
                SchemaCoding.Support.structProperty(
                  name: "b",
                  keyPath: \Self.b,
                  schema: SchemaCoding.Support.schema(
                    representing: Bool.self
                  )
                )
                SchemaCoding.Support.structProperty(
                  name: "c",
                  keyPath: \Self.c,
                  schema: SchemaCoding.Support.schema(
                    representing: String.self
                  )
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
    "SchemaProperty": MacroSpec(type: SchemaPropertyMacro.self),
  ]
}

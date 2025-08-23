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
      // MARK: - Some Unrelated Comment

      @SchemaCodable(
        description: "Test Struct"
      )
      public struct TestStruct {
        let anInteger: Int

        @SchemaDetails(
          description: "A coordinate"
        )
        let aCoordinate: (Int, Int)

        // Crazy Declaration
        let a, b: Bool, c: String
      }
      """,
      expandedSource: #####"""
        // MARK: - Some Unrelated Comment
        public struct TestStruct {
          let anInteger: Int
          let aCoordinate: (Int, Int)

          // Crazy Declaration
          let a, b: Bool, c: String
        }

        extension TestStruct: SchemaCoding.SchemaCodable {
          public static var schema: some SchemaCoding.ObjectSchema<Self> {
            let anInteger = SchemaCoding.SchemaCodingSupport.StructPropertyDefinition(
              name: __macro_local_17PropertyCodingKeyfMu_.anInteger,
              keyPath: \Self.anInteger,
              schema: SchemaCoding.SchemaCodingSupport.schema(representing: Int.self)
            )
            let aCoordinate = SchemaCoding.SchemaCodingSupport.StructPropertyDefinition(
              name: __macro_local_17PropertyCodingKeyfMu_.aCoordinate,
              description: "A coordinate",
              keyPath: \Self.aCoordinate,
              schema: SchemaCoding.SchemaCodingSupport.schema(representing: (Int, Int).self)
            )
            let a = SchemaCoding.SchemaCodingSupport.StructPropertyDefinition(
              name: __macro_local_17PropertyCodingKeyfMu_.a,
              keyPath: \Self.a,
              schema: SchemaCoding.SchemaCodingSupport.schema(representing: Bool.self)
            )
            let b = SchemaCoding.SchemaCodingSupport.StructPropertyDefinition(
              name: __macro_local_17PropertyCodingKeyfMu_.b,
              keyPath: \Self.b,
              schema: SchemaCoding.SchemaCodingSupport.schema(representing: Bool.self)
            )
            let c = SchemaCoding.SchemaCodingSupport.StructPropertyDefinition(
              name: __macro_local_17PropertyCodingKeyfMu_.c,
              keyPath: \Self.c,
              schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self)
            )
            return SchemaCoding.SchemaCodingSupport.structSchema(
              representing: Self.self,
              description: "Test Struct",
              properties: (anInteger, aCoordinate, a, b, c),
              initializer: Self.init(structSchemaDecoder:)
            )
          }
          private init(structSchemaDecoder: SchemaCoding.SchemaCodingSupport.StructSchemaDecoder<Int, (Int, Int), Bool, Bool, String>) {
            self.anInteger = structSchemaDecoder.propertyValues.0
            self.aCoordinate = structSchemaDecoder.propertyValues.1
            self.a = structSchemaDecoder.propertyValues.2
            self.b = structSchemaDecoder.propertyValues.3
            self.c = structSchemaDecoder.propertyValues.4
          }
          private enum __macro_local_17PropertyCodingKeyfMu_: Swift.String, Swift.CodingKey {
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
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self),
    "SchemaDetails": MacroSpec(type: SchemaDetailsMacro.self),
  ]
}

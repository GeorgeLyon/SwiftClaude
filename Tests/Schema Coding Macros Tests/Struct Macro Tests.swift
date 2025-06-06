import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import SchemaCodingMacros

@Suite("@SchemaCodable Struct")
private struct StructMacroTests {

  @Test
  func testStructMacro() {

    assertMacroExpansion(
      """
      /// A test struct
      @SchemaCodable
      struct TestStruct {
        let anInteger: Int
        /// An (x, y) coordinate
        let aCoordinate: (Int, Int)
        // Crazy Declaration
        let a, b: Bool, c: String
      }
      """,
      expandedSource: ##"""
        /// A test struct
        struct TestStruct {
          let anInteger: Int
          /// An (x, y) coordinate
          let aCoordinate: (Int, Int)
          // Crazy Declaration
          let a, b: Bool, c: String
        }

        extension TestStruct: SchemaCoding.SchemaCodable {
          static var schema: some Schema<Self> {
            SchemaProvider.structSchema(
              representing: Self.self,
              description: #"""
              A test struct
              """#,
              properties: (
                (
                  description: nil,
                  keyPath: \Self.anInteger,
                  key: "anInteger" as SchemaCodingKey,
                  schema: SchemaProvider.schema(representing: Int.self)
                ),
                (
                  description: #"""
                  An (x, y) coordinate
                  """#,
                  keyPath: \Self.aCoordinate,
                  key: "aCoordinate" as SchemaCodingKey,
                  schema: SchemaProvider.schema(representing: (Int, Int).self)
                ),
                (
                  description: #"""
                  Crazy Declaration
                  """#,
                  keyPath: \Self.c,
                  key: "c" as SchemaCodingKey,
                  schema: SchemaProvider.schema(representing: String.self)
                ),
                (
                  description: #"""
                  Crazy Declaration
                  """#,
                  keyPath: \Self.b,
                  key: "b" as SchemaCodingKey,
                  schema: SchemaProvider.schema(representing: Bool.self)
                ),
                (
                  description: #"""
                  Crazy Declaration
                  """#,
                  keyPath: \Self.a,
                  key: "a" as SchemaCodingKey,
                  schema: SchemaProvider.schema(representing: Bool.self)
                )
              ),
              initializer: Self.init(structSchemaDecoder:)
            )
          }
          private init(structSchemaDecoder: SchemaProvider.StructSchemaDecoder<Int, (Int, Int), String, Bool, Bool>) {
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
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self)
  ]
}

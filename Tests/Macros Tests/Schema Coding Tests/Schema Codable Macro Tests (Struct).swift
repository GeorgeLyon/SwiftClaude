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
      // MARK: - Some Unrealated Comment

      /// A test struct
      /// Two lines of comments
      @SchemaCodable
      public struct TestStruct {
        let anInteger: Int
        /// An (x, y) coordinate
        let aCoordinate: (Int, Int)
        // Crazy Declaration
        let a, b: Bool, c: String
      }
      """,
      expandedSource: #####"""
        // MARK: - Some Unrealated Comment

        /// A test struct
        /// Two lines of comments
        public struct TestStruct {
          let anInteger: Int
          /// An (x, y) coordinate
          let aCoordinate: (Int, Int)
          // Crazy Declaration
          let a, b: Bool, c: String
        }

        extension TestStruct: SchemaCoding.SchemaCodable {
          public static var schema: some SchemaCoding.SchemaCodingSupport.ExtendableSchema<Self> {
            SchemaCoding.SchemaCodingSupport.structSchema(
              representing: Self.self,
              description: ####"""
              A test struct\####nTwo lines of comments
              """####,
              properties: (
                (
                  description: nil,
                  keyPath: \Self.anInteger,
                  key: "anInteger" as SchemaCoding.SchemaCodingSupport.CodingKey,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: Int.self)
                ),
                (
                  description: ####"""
                  An (x, y) coordinate
                  """####,
                  keyPath: \Self.aCoordinate,
                  key: "aCoordinate" as SchemaCoding.SchemaCodingSupport.CodingKey,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: (Int, Int).self)
                ),
                (
                  description: ####"""
                  Crazy Declaration
                  """####,
                  keyPath: \Self.c,
                  key: "c" as SchemaCoding.SchemaCodingSupport.CodingKey,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self)
                ),
                (
                  description: ####"""
                  Crazy Declaration
                  """####,
                  keyPath: \Self.b,
                  key: "b" as SchemaCoding.SchemaCodingSupport.CodingKey,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: Bool.self)
                ),
                (
                  description: ####"""
                  Crazy Declaration
                  """####,
                  keyPath: \Self.a,
                  key: "a" as SchemaCoding.SchemaCodingSupport.CodingKey,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: Bool.self)
                )
              ),
              initializer: Self.init(structSchemaDecoder:)
            )
          }
          private init(structSchemaDecoder: SchemaCoding.SchemaCodingSupport.StructSchemaDecoder<Int, (Int, Int), String, Bool, Bool>) {
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
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self)
  ]
}

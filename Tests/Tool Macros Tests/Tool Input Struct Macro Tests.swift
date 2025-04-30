import Foundation
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import ToolMacros

@Suite
private struct ClaudeMacroTests {

  @Test
  func testStructMacro() {

    assertMacroExpansion(
      """
      @ToolInput
      struct ToolInputStruct {
        let anInteger: Int

        /// An (x, y) coordinate
        let aCoordinate: (Int, Int)

        // Crazy Declaration
        let a, b: Bool, c: String
      }
      """,
      expandedSource: #"""
        struct ToolInputStruct {
          let anInteger: Int

          /// An (x, y) coordinate
          let aCoordinate: (Int, Int)

          // Crazy Declaration
          let a, b: Bool, c: String
        }

        extension MyTool: ToolInput.SchemaCodable {

          var toolInputSchema: some ToolInput.Schema<Self> {
            ToolInput.structSchema(
              representing: Person.self,
              description: "A person object",
              keyedBy: PropertyKey.self,
              properties: (
                (
                  key: .anInteger,
                  description: nil,
                  keyPath: \.anInteger,
                  schema: ToolInput.schema(representing: Int.self)
                ),
                (
                  key: .aCoordinate,
                  description: "An (x, y) coordinate",
                  keyPath: \.aCoordinate,
                  schema: ToolInput.schema(representing: (Int, Int).self)
                )
              ),
              initializer: Self.init(structSchemaDecoder:)
            )
          }

          private enum ToolInputSchemaPropertyKey: Swift.CodingKey {
            case anInteger
            case aCoordinate
          }

          private init(
            structSchemaDecoder: ToolInput.StructSchemaDecoder<Int, (Int, Int)>
          ) {
            anInteger = structSchemaDecoder.propertyValues.0
            aCoordinate = structSchemaDecoder.propertyValues.1
          }

        }
        """#,
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

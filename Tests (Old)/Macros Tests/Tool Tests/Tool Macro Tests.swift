import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros
/*
@Suite("@Tool")
struct ToolMacroTests {

  @Test
  func testToolMacro() {

    assertMacroExpansion(
      """
      @Tool(
        description: "A tool with a single action"
      )
      actor MyTool {
        func invoke(_ a: Int, b: String, `c`: Bool) {}
      }
      """,
      expandedSource: #####"""
        actor MyTool {
          func invoke(_ a: Int, b: String, `c`: Bool) {}
        }

        extension MyTool: Tool {
          nonisolated var definition: some ToolDefinition<Input> {
            CustomToolDefinition(
              name: "\(Self.self)",
              description: "A tool with a single action",
              inputSchema: Input.schema
            )
          }
          func invoke(with input: Input, isolation: isolated Actor) async {
            await input.__macro_local_6invokefMu_(
              tool: self,
              isolation: #isolation
            )
          }
          struct Input: ToolInput.SchemaCodable {
            private let a: Int
            private let b: String
            private let c: Bool
            static var schema: some ToolInput.ObjectSchema<Self> {
              let a = ToolInput.SchemaCodingSupport.StructPropertyDefinition(
                name: __macro_local_12PropertyNamefMu_.a,
                keyPath: \Self.a,
                schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)
              )
              let b = ToolInput.SchemaCodingSupport.StructPropertyDefinition(
                name: __macro_local_12PropertyNamefMu_.b,
                keyPath: \Self.b,
                schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)
              )
              let c = ToolInput.SchemaCodingSupport.StructPropertyDefinition(
                name: __macro_local_12PropertyNamefMu_.c,
                keyPath: \Self.c,
                schema: ToolInput.SchemaCodingSupport.schema(representing: Bool.self)
              )
              return ToolInput.SchemaCodingSupport.structSchema(
                representing: Self.self,
                properties: (a, b, c),
                initializer: Self.init(structSchemaDecoder:)
              )
            }
            private init(structSchemaDecoder: ToolInput.SchemaCodingSupport.StructSchemaDecoder<Int, String, Bool>) {
              self.a = structSchemaDecoder.propertyValues.0
              self.b = structSchemaDecoder.propertyValues.1
              self.c = structSchemaDecoder.propertyValues.2
            }
            private enum __macro_local_12PropertyNamefMu_: Swift.String, Swift.CodingKey {
              case a = "a"
              case b = "b"
              case c = "c"
            }
            fileprivate func __macro_local_6invokefMu_(tool: __macro_local_4ToolfMu_, isolation: isolated Actor) async -> __macro_local_4ToolfMu_.Output {
              await tool.invoke(
                self.a,
                b: self.b,
                c: self.c
              )
            }
          }
          typealias __macro_local_4ToolfMu_ = MyTool
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
    "Tool": MacroSpec(type: ToolMacro.self),
    "SchemaProperty": MacroSpec(type: SchemaPropertyMacro.self),
  ]
}
*/

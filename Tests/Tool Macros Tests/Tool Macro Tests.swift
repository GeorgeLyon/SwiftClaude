import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import ToolMacros

@Suite("@Tool")
private struct ToolMacroTests {

  @Test
  func testToolMacro() {

    assertMacroExpansion(
      """
      /// A tool with a single action
      @Tool
      actor MyTool {
        func invoke(_ a: Int, b: String, `c`: Bool) {}
      }
      """,
      expandedSource: ##"""
        /// A tool with a single action
        actor MyTool {
          func invoke(_ a: Int, b: String, `c`: Bool) {}
        }

        extension MyTool: Tool {
          nonisolated var definition: some ToolDefinition<Input> {
            ClientDefinedToolDefinition(
              name: "\(Self.self)",
              description: #"""
              A tool with a single action
              """#,
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
            static var schema: some Schema<Self> {
              SchemaProvider.structSchema(
                representing: Self.self,
                description: #"""
                A tool with a single action
                """#,
                keyedBy: __macro_local_11PropertyKeyfMu_.self,
                properties: (
                  (
                    description: nil,
                    keyPath: \Self.a,
                    key: __macro_local_11PropertyKeyfMu_.a,
                    schema: SchemaProvider.schema(representing: Int.self)
                  ),
                  (
                    description: nil,
                    keyPath: \Self.b,
                    key: __macro_local_11PropertyKeyfMu_.b,
                    schema: SchemaProvider.schema(representing: String.self)
                  ),
                  (
                    description: nil,
                    keyPath: \Self.c,
                    key: __macro_local_11PropertyKeyfMu_.c,
                    schema: SchemaProvider.schema(representing: Bool.self)
                  )
                ),
                initializer: Self.init(structSchemaDecoder:)
              )
            }
            private enum __macro_local_11PropertyKeyfMu_: Swift.CodingKey {
              case a
              case b
              case c
            }
            private init(structSchemaDecoder: SchemaProvider.StructSchemaDecoder<Int, String, Bool>) {
              self.a = structSchemaDecoder.propertyValues.0
              self.b = structSchemaDecoder.propertyValues.1
              self.c = structSchemaDecoder.propertyValues.2
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
    "Tool": MacroSpec(type: ToolMacro.self)
  ]
}

import Claude
import Foundation
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import ClaudeMacros

@Suite
private struct ClaudeMacroTests {

  @Test
  func testSimpleMacro() {

    assertMacroExpansion(
      """
      @Tool
      struct MyTool {
        func invoke(foo: Int) {
        }
      }
      """,
      expandedSource: #"""
        struct MyTool {
          func invoke(foo: Int) {
          }
        }

        extension MyTool: Claude.Tool {
          var definition: Claude.ToolDefinition<MyTool> {
            Claude.ToolDefinition.userDefined(tool: MyTool.self, name: "\(MyTool.self)", description: """

            """)
          }
          struct Input: Claude.ToolInput {
            let foo: Int
            typealias ToolInputSchema = Claude.ToolInputKeyedTupleSchema<Int.ToolInputSchema>
            static var toolInputSchema: ToolInputSchema {
              ToolInputSchema((key: Claude.ToolInputSchemaKey("foo"), schema: Int.toolInputSchema))
            }
            init(toolInputSchemaDescribedValue value: ToolInputSchema.DescribedValue) throws {
              self.foo = try .init(toolInputSchemaDescribedValue: value)
            }
            var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
              (foo.toolInputSchemaDescribedValue)
            }
          }
          func invoke(with input: Input, in context: Claude.ToolInvocationContext<MyTool>, isolation: isolated Actor) async {
            invoke(foo: input.foo)
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
    "Tool": MacroSpec(type: ToolMacro.self)
  ]
}

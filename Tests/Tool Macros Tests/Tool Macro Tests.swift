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
      struct MyTool {
        
        func invoke(_ a: Int, b: String, `c`: Bool) {
          
        }
        
      }
      """,
      expandedSource: ##"""
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

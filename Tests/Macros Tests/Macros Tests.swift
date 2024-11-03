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
      expandedSource: """
        struct X {
        }
        """,
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

  private func expandMacros
  private let macroSpecs = [
    "Tool": MacroSpec(type: ToolMacro.self)
  ]
}

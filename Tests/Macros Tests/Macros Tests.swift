import Foundation
import Testing
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import ClaudeMacros

@Suite
private struct ClaudeMacroTests {
  private let macros = ["Tool": ToolMacro.self]
  
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
        class MyClass {
          func __macro_local_6uniquefMu_() {
          }
        }
        """#,
      macros: macros,
      indentationWidth: .spaces(2)
    )
  }
  
}

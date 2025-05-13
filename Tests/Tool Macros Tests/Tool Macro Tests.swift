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
        
        /// Perform an action with two arguments
        @Action
        func performAction(
          with argument1: String, 
          and argument2: Int
        ) async throws -> ToolResultContent
        
        /// Perform an action with no arguments
        @Action
        func performOtherAction()
      
        @Action
        func performThirdAction(_ x: Int, _ y: Int) -> String
            
        @Action
        func performSingleArgumentAction(_ x: Bool) -> String
      
      }
      """,
      expandedSource: ##"""
        /// A tool with a single action
        @Tool
        struct MyTool {
          
          /// Perform an action with two arguments
          @Action
          func performAction(
            with argument1: String, 
            and argument2: Int
          ) async throws -> ToolResultContent
          
          /// Perform an action with no arguments
          @Action
          func performOtherAction()
        
          @Action
          func performThirdAction(_ x: Int, _ y: Int) -> String
              
          @Action
          func performSingleArgumentAction(_ x: Bool) -> String
        
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
    "ToolInput": MacroSpec(type: ToolInputMacro.self)
  ]
}

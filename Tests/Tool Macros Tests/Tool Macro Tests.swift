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
            ) async throws -> Int {
              fatalError()
            }
            
            /// Perform an action with no arguments
            @Action
            func performOtherAction() {
              
            }
          
            @Action
            func performThirdAction(_ x: Int, _ y: Int) -> String {
              fatalError()
            }
                
            @Action
            func performSingleArgumentAction(_ x: Bool) -> String {
              fatalError()
            }
          
          }
        """##
        //        + ##"""
        //        extension MyTool: Tool {
        //
        //            struct Input: ToolInput {
        //
        //              fileprivate invoke(on tool: MyTool) -> Output {
        //                switch invocation {
        //                  case .performAction:
        //                  case .performOtherAction:
        //                  case .performThirdAction:
        //                  case .performSingleArgumentAction:
        //                }
        //              }
        //
        //              private enum Invocation {
        //                case performAction(with argument1: String, and argument2: Int)
        //                case performOtherAction
        //                case performThirdAction(_ x: Int, _ y: Int)
        //                case performSingleArgumentAction(_ x: Bool)
        //              }
        //              private let invocation: Invocation
        //
        //            }
        //
        //        }
        //        """##
      ,
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

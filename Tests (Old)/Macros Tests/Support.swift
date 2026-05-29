import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

func assertMacroExpansion(
  _ originalSource: String,
  expandedSource expectedExpandedSource: String,
  macroSpecs: [String: MacroSpec],
) {
  assertMacroExpansion(
    originalSource,
    expandedSource: expectedExpandedSource,
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

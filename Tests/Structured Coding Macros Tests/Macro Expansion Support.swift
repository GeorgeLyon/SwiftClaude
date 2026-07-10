import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import StructuredCodingMacros

private let macroSpecs: [String: MacroSpec] = [
  "StructuredCodable": MacroSpec(type: StructuredCodableMacro.self),
  "StructuredProperty": MacroSpec(type: StructuredPropertyMacro.self),
  "StructuredCase": MacroSpec(type: StructuredCaseMacro.self),
  "StructuredAction": MacroSpec(type: StructuredActionMacro.self),
  "StructuredTool": MacroSpec(type: StructuredToolMacro.self),
]

/// Asserts that the `@StructuredCodable` family of macros expands `original` into
/// `expanded`, emitting exactly `diagnostics`. Shared by the struct, enum, and
/// callable expansion suites. The `__macro_local_…` names in the expected sources
/// are the unique names the macro generates for the per-property / per-case type
/// aliases.
func assertStructuredCodableExpansion(
  _ original: String,
  _ expanded: String,
  diagnostics: [DiagnosticSpec] = []
) {
  assertMacroExpansion(
    original,
    expandedSource: expanded,
    diagnostics: diagnostics,
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

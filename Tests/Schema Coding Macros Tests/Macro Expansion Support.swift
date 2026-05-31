import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import SchemaCodingMacros

private let macroSpecs: [String: MacroSpec] = [
  "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self),
  "SchemaProperty": MacroSpec(type: SchemaPropertyMacro.self),
  "SchemaCase": MacroSpec(type: SchemaCaseMacro.self),
]

/// Asserts that the `@SchemaCodable` family of macros expands `original` into
/// `expanded`. Shared by the struct and enum expansion suites. The
/// `__macro_local_…` names in the expected sources are the unique names the macro
/// generates for the per-property / per-case type aliases.
func assertSchemaCodableExpansion(_ original: String, _ expanded: String) {
  assertMacroExpansion(
    original,
    expandedSource: expanded,
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

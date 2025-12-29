import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct SchemaCodableMacroContext {
  let namespace: SchemaCodingNamespace
  let macroAttribute: TypeSyntax
  let detailMacroAttribute: TypeSyntax
  let defaultKeyConversionStrategy: KeyConversionStrategy
  let defaultEnumStyle: EnumStyleArgument?
  let expansionContext: MacroExpansionContext
}

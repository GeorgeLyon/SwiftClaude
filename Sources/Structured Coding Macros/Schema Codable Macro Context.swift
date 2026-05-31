import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct SchemaCodableMacroContext {
  let namespace: SchemaCodingNamespace
  let macroAttribute: TypeSyntax
  let defaultKeyConversionStrategy: KeyConversionStrategy
  let defaultEnumStyle: EnumStyleArgument?
  let extendedType: TypeSyntax
  let expansionContext: MacroExpansionContext
}

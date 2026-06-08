import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct StructuredCodableMacroContext {
  let namespace: StructuredCodingNamespace
  let macroAttribute: TypeSyntax
  let defaultKeyConversionStrategy: KeyConversionStrategy
  let defaultEnumStyle: EnumStyleArgument?
  let extendedType: TypeSyntax
  let expansionContext: MacroExpansionContext
}

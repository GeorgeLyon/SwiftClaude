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
  /// Modes the declaration needs regardless of what the attribute spells —
  /// see `CompatibilityModes.init(inferredFrom:in:)`. Unioned with any
  /// explicit `compatibilityMode:` argument.
  let inferredCompatibilityModes: CompatibilityModes
  let expansionContext: MacroExpansionContext
}

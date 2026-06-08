import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ToolInputMacro: StructuredCodableMacroProtocol {
  static let structuredCodingNamespace: StructuredCodingNamespace = "ToolInput"
  static let structuredCodableMacroAttribute: TypeSyntax = "ToolInput"
  static let defaultKeyConversionStrategy: KeyConversionStrategy = .none
  static let defaultEnumStyle: EnumStyleArgument? = nil
}

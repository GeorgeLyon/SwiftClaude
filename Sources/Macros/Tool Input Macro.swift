import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ToolInputMacro: SchemaCodableMacroProtocol {
  static let schemaCodingNamespace: SchemaCodingNamespace = "ToolInput"
  static let schemaCodableMacroAttribute: TypeSyntax = "ToolInput"
  static let schemaDetailsMacroAttribute: TypeSyntax = "ToolInputDetails"
  static let defaultCodingKeyConversionStrategy: CodingKeyConversionStrategy = .none
  static let defaultEnumStyle: EnumStyleArgument? = nil
}

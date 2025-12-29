import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ToolInputMacro: SchemaCodableMacroProtocol {
  static let schemaCodingNamespace: SchemaCodingNamespace = "ToolInput"
  static let schemaCodableMacroAttribute: TypeSyntax = "ToolInput"
  static let schemaParametersMacroAttribute: TypeSyntax = "ToolInputParameters"
  static let defaultKeyConversionStrategy: KeyConversionStrategy = .none
  static let defaultEnumStyle: EnumStyleArgument? = nil
}

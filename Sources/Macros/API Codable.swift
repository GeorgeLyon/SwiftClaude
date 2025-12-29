import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct APICodableMacro: SchemaCodableMacroProtocol {
  static let schemaCodingNamespace: SchemaCodingNamespace = "APICodable"
  static let schemaCodableMacroAttribute: TypeSyntax = "APICodable"
  static let schemaParametersMacroAttribute: TypeSyntax = "APICodingParameters"
  static let defaultKeyConversionStrategy: KeyConversionStrategy = .convertToSnakeCase
  static let defaultEnumStyle: EnumStyleArgument? = .internallyTagged(
    discriminatorPropertyName: StringLiteralExprSyntax(content: "type")
  )
}

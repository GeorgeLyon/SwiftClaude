import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct APICodableMacro: SchemaCodableMacroProtocol {
  static let schemaCodingNamespace: SchemaCodingNamespace = "APICodable"
  static let schemaCodableMacroAttribute: TypeSyntax = "APICodable"
  static let schemaDetailsMacroAttribute: TypeSyntax = "APIDetails"
  static let defaultCodingKeyConversionStrategy: CodingKeyConversionStrategy = .convertToSnakeCase
  static let defaultEnumStyle: EnumStyleArgument? = .internallyTagged(
    discriminatorPropertyName: StringLiteralExprSyntax(content: "type")
  )
}

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct APICodableMacro: StructuredCodableMacroProtocol {
  static let structuredCodingNamespace: StructuredCodingNamespace = "APICodable"
  static let structuredCodableMacroAttribute: TypeSyntax = "APICodable"
  static let defaultKeyConversionStrategy: KeyConversionStrategy = .convertToSnakeCase
  static let defaultEnumStyle: EnumStyleArgument? = .internallyTagged(
    discriminatorPropertyName: StringLiteralExprSyntax(content: "type")
  )
}

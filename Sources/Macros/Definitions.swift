import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct IdentifiableToken {
  let identifier: Identifier
  let token: TokenSyntax
  var name: String {
    identifier.name
  }
}

struct StructSchema {
  let namespace: SchemaCodingNamespace
  let typeName: TokenSyntax
  let additionalArguments: LabeledExprListSyntax
  let propertyNameTypeName: TokenSyntax
  let codingKeyConversionStrategy: CodingKeyConversionStrategy

  struct Property {
    let name: IdentifiableToken
    let type: TypeSyntax
    let additionalArguments: LabeledExprListSyntax
    let isInitializedConstantProperty: Bool
  }
  let properties: [Property]
}

struct EnumSchema {
  let namespace: SchemaCodingNamespace
  let typeName: TokenSyntax
  let additionalArguments: LabeledExprListSyntax
  let caseNameTypeName: TokenSyntax
  let codingKeyConversionStrategy: CodingKeyConversionStrategy

  struct AssociatedValue {
    let name: IdentifiableToken?
    let argumentLabel: TokenSyntax?
    let bindingName: TokenSyntax
    let type: TypeSyntax
  }
  struct Case {
    let name: IdentifiableToken
    let associatedValueLabelTypeName: TokenSyntax
    let additionalArguments: LabeledExprListSyntax
    let associatedValues: [AssociatedValue]
  }
  let cases: [Case]
}

struct SchemaCodableType {

  var namespace: SchemaCodingNamespace {
    switch schemaKind {
    case .struct(let schema):
      return schema.namespace
    case .enum(let schema):
      return schema.namespace
    }
  }

  var codingKeyConversionStrategy: CodingKeyConversionStrategy {
    switch schemaKind {
    case .struct(let schema):
      return schema.codingKeyConversionStrategy
    case .enum(let schema):
      return schema.codingKeyConversionStrategy
    }
  }

  let isPublic: Bool

  enum SchemaKind {
    case `struct`(StructSchema)
    case `enum`(EnumSchema)
  }
  let schemaKind: SchemaKind
}

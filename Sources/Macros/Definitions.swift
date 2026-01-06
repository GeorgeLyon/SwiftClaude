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
  let style: StructStyleArgument?
  let keyConversionStrategy: KeyConversionStrategy

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
  let keyConversionStrategy: KeyConversionStrategy

  struct AssociatedValue {
    let name: IdentifiableToken?
    let argumentLabel: TokenSyntax?
    let bindingName: TokenSyntax
    let type: TypeSyntax
  }
  struct Case {
    let name: IdentifiableToken
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

  var keyConversionStrategy: KeyConversionStrategy {
    switch schemaKind {
    case .struct(let schema):
      return schema.keyConversionStrategy
    case .enum(let schema):
      return schema.keyConversionStrategy
    }
  }

  let isPublic: Bool

  enum SchemaKind {
    case `struct`(StructSchema)
    case `enum`(EnumSchema)
  }
  let schemaKind: SchemaKind
}

// MARK: - Callable Schema

struct CallableSchema {
  let namespace: SchemaCodingNamespace
  let name: TokenSyntax
  let fullName: String
  let parameters: [Parameter]
  let returnType: ReturnType
  let isAsync: Bool
  let throwsClause: ThrowsClauseSyntax?
  let isMethod: Bool

  struct Parameter {
    let firstName: TokenSyntax
    let secondName: TokenSyntax?
    let type: TypeSyntax

    var isLabeled: Bool {
      firstName.tokenKind != .wildcard
    }

    var effectiveName: TokenSyntax {
      secondName ?? firstName
    }
  }

  enum ReturnType {
    case void
    case single(TypeSyntax)
    case tuple([(label: TokenSyntax?, type: TypeSyntax)])
  }
}

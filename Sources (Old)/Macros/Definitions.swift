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

struct SchemaType {
  let syntax: TypeSyntax

  enum Kind {
    case optionalTuple([TypeSyntax])
    case tuple([TypeSyntax])
    case other(TypeSyntax)
  }
  let kind: Kind
}

struct SchemaParameter {
  let firstName: TokenSyntax
  let secondName: TokenSyntax?
  let type: SchemaType
  let bindingName: TokenSyntax

  var isLabeled: Bool {
    firstName.tokenKind != .wildcard
  }

  var effectiveName: TokenSyntax {
    secondName ?? firstName
  }

  /// The label to use in parameter() calls - nil if unlabeled
  var label: TokenSyntax? {
    isLabeled ? firstName : nil
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
    let type: SchemaType
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

  struct Case {
    let name: IdentifiableToken
    let additionalArguments: LabeledExprListSyntax
    let associatedValues: [SchemaParameter]
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
  let additionalArguments: LabeledExprListSyntax
  let keyConversionStrategy: KeyConversionStrategy
  let parameters: [SchemaParameter]
  let returnType: ReturnType
  let isAsync: Bool
  let throwsClause: ThrowsClauseSyntax?
  let isMethod: Bool

  enum ReturnType {
    case void
    case single(TypeSyntax)
    case tuple([(label: TokenSyntax?, type: TypeSyntax)])
  }
}

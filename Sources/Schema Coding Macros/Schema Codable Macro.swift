import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Macro

enum SchemaCodableMacro: SchemaCodableMacroProtocol {
  static let schemaCodingNamespace: SchemaCodingNamespace = "SchemaCoding"
  static let schemaCodableMacroAttribute: TypeSyntax = "SchemaCodable"
  static let defaultKeyConversionStrategy: KeyConversionStrategy = .none
  static let defaultEnumStyle: EnumStyleArgument? = nil
}

// MARK: - Protocol

protocol SchemaCodableMacroProtocol: ExtensionMacro {
  static var schemaCodingNamespace: SchemaCodingNamespace { get }
  static var schemaCodableMacroAttribute: TypeSyntax { get }
  static var defaultKeyConversionStrategy: KeyConversionStrategy { get }
  static var defaultEnumStyle: EnumStyleArgument? { get }
}

extension SchemaCodableMacroProtocol {
  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let context = SchemaCodableMacroContext(
      namespace: Self.schemaCodingNamespace,
      macroAttribute: Self.schemaCodableMacroAttribute,
      defaultKeyConversionStrategy: Self.defaultKeyConversionStrategy,
      defaultEnumStyle: Self.defaultEnumStyle,
      extendedType: TypeSyntax(type),
      expansionContext: context
    )
    let schemaCodableType = declaration.schemaCodableType(in: context)
    return [
      ExtensionDeclSyntax(
        extendedType: type,
        inheritanceClause: InheritanceClauseSyntax {
          InheritedTypeSyntax(
            type: context.namespace.memberType(name: "SchemaCodable")
          )
        }
      ) {
        if let schemaCodableType {
          schemaCodableType.members
        }
      }
    ]
  }

}

// MARK: - Schema Property

enum SchemaPropertyMacro: PeerMacro {

  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    return []
  }

}

// MARK: - Schema Case

enum SchemaCaseMacro: PeerMacro {

  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    return []
  }

}

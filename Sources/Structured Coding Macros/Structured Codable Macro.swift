import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Macro

enum StructuredCodableMacro: StructuredCodableMacroProtocol {
  static let structuredCodingNamespace: StructuredCodingNamespace = "StructuredCoding"
  static let structuredCodableMacroAttribute: TypeSyntax = "StructuredCodable"
  static let defaultKeyConversionStrategy: KeyConversionStrategy = .none
  static let defaultEnumStyle: EnumStyleArgument? = nil
}

// MARK: - Protocol

protocol StructuredCodableMacroProtocol: ExtensionMacro, MemberMacro {
  static var structuredCodingNamespace: StructuredCodingNamespace { get }
  static var structuredCodableMacroAttribute: TypeSyntax { get }
  static var defaultKeyConversionStrategy: KeyConversionStrategy { get }
  static var defaultEnumStyle: EnumStyleArgument? { get }
}

extension StructuredCodableMacroProtocol {
  static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let context = StructuredCodableMacroContext(
      namespace: Self.structuredCodingNamespace,
      macroAttribute: Self.structuredCodableMacroAttribute,
      defaultKeyConversionStrategy: Self.defaultKeyConversionStrategy,
      defaultEnumStyle: Self.defaultEnumStyle,
      extendedType: TypeSyntax(type),
      inferredCompatibilityModes: CompatibilityModes(inferredFrom: declaration, in: context),
      expansionContext: context
    )
    guard let structuredCodableType = declaration.structuredCodableType(in: context) else {
      return []
    }
    return [
      ExtensionDeclSyntax(
        extendedType: type,
        inheritanceClause: InheritanceClauseSyntax {
          for conformanceType in structuredCodableType.conformanceTypes {
            InheritedTypeSyntax(type: conformanceType)
          }
        }
      ) {
        structuredCodableType.members
      }
    ]
  }

  /// The member role exists for classes: their decoder initializer must be
  /// declared directly in the class body (a stored-property-assigning
  /// initializer is designated, and both designated and `required`
  /// initializers are forbidden in extensions). Structs and enums produce no
  /// body members — bailing out before parsing also keeps their diagnostics
  /// from being emitted twice, and a non-final class bails silently so the
  /// extension role diagnoses the finality requirement exactly once.
  static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self),
      classDecl.modifiers.contains(where: \.isFinal)
    else {
      return []
    }
    let context = StructuredCodableMacroContext(
      namespace: Self.structuredCodingNamespace,
      macroAttribute: Self.structuredCodableMacroAttribute,
      defaultKeyConversionStrategy: Self.defaultKeyConversionStrategy,
      defaultEnumStyle: Self.defaultEnumStyle,
      extendedType: TypeSyntax(IdentifierTypeSyntax(name: classDecl.name.trimmed)),
      inferredCompatibilityModes: CompatibilityModes(inferredFrom: declaration, in: context),
      expansionContext: context
    )
    guard let structuredCodableType = declaration.structuredCodableType(in: context) else {
      return []
    }
    return structuredCodableType.bodyMembers
  }

}

// MARK: - Structured Property

enum StructuredPropertyMacro: PeerMacro {

  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    return []
  }

}

// MARK: - Structured Case

enum StructuredCaseMacro: PeerMacro {

  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    return []
  }

}

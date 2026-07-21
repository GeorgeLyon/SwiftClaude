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

protocol StructuredCodableMacroProtocol: ExtensionMacro {
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

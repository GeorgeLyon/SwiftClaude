// MARK: - Structured Codable

/// Synthesizes structured-coding conformance for the attached declaration:
/// a `StructuredObject` conformance for a `struct` or `class`, or a
/// `StructuredEnumeration` conformance for an `enum`.
///
/// An object conformance declares a structural `Schema` typealias
/// (`StructuredObjectSchema<Self, …>`); pack-generic objects
/// (`.variadicGenerics`) and enumerations instead type-erase to
/// `StructuredAnySchema`, because naming a structural schema for a pack-generic
/// type crashes the runtime demangler.
///
/// - Parameters:
///   - description: A human-readable description of the type.
///   - style: How an enumeration's cases are represented; ignored for objects.
///   - keyConversionStrategy: How Swift property and case names are converted
///     into JSON keys.
///   - compatibilityMode: Workarounds for Swift toolchain limitations to apply
///     when generating the conformance; see `StructuredCodingCompatibilityMode`.
@attached(
  extension,
  conformances: StructuredObject, StructuredEnumeration,
  names:
    named(Schema),
    named(schema),
    named(StructuredObjectProperties),
    named(properties),
    named(ObjectDecoderValues),
    named(decode),
    named(init),
    named(Cases),
    named(cases),
    named(codingStyle)
)
public macro StructuredCodable(
  description: String? = nil,
  style: any StructuredEnumerationCodingStyle = .objectProperties,
  keyConversionStrategy: StructuredCodingKeyConversionStrategy = .none,
  compatibilityMode: StructuredCodingCompatibilityMode = []
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "StructuredCodableMacro"
  )

// MARK: - Member Annotations

/// Attaches a description to a stored property of a `@StructuredCodable` type.
@attached(peer)
public macro StructuredProperty(
  description: String
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "StructuredPropertyMacro"
  )

/// Attaches a description to a case of a `@StructuredCodable` enumeration.
@attached(peer)
public macro StructuredCase(
  description: String
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "StructuredCaseMacro"
  )

// MARK: - Compatibility Mode

/// Workarounds for Swift toolchain limitations that `@StructuredCodable` applies
/// when generating a conformance.
public struct StructuredCodingCompatibilityMode: OptionSet, Sendable {

  /// Accesses stored properties through getter closures instead of key path
  /// literals, allowing `@StructuredCodable` to be applied to types whose
  /// generic signature contains a parameter pack (`each T`).
  ///
  /// By default, the generated `properties()` references each stored property
  /// with a key path literal (`keyPath: \.foo`). As of Swift 6.3, forming a key
  /// path literal whose `Root` captures a parameter pack crashes at runtime:
  /// `_swift_getKeyPath` resolves the pattern's generic-argument references
  /// through the runtime demangler, which aborts with "Pack expansion count
  /// type should be a pack" when those references contain pack expansions.
  /// Constructing values of the type is fine — the trap fires the first time
  /// one of its key paths is instantiated, e.g.:
  ///
  /// ```swift
  /// struct PackGeneric<each T> {
  ///   var description: String?
  /// }
  /// _ = PackGeneric<Int, String>(description: "hi")    // ok
  /// _ = \PackGeneric<Int, String>.description           // runtime crash
  /// ```
  ///
  /// With this option set, every property is instead accessed through a
  /// get-only closure (`getter: { $0.foo }`), which never touches the key path
  /// runtime. The trade-off is that the coding machinery sees all properties
  /// as immutable: values are produced only through the generated
  /// `decode(from:)` path, and decoding strategies that write into an existing
  /// value in place (which require a `WritableKeyPath`) are unavailable.
  ///
  /// Only set this option on types that actually have a parameter pack in
  /// their generic signature; remove it once the Swift runtime supports key
  /// paths rooted in pack-generic types.
  public static let variadicGenerics = Self(rawValue: 1 << 0)

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
  public let rawValue: Int

}

// MARK: - Key Conversion Strategy

/// How `@StructuredCodable` converts Swift property and case names into JSON keys.
public enum StructuredCodingKeyConversionStrategy: Sendable {
  /// Use the Swift name as-is.
  case none
  /// Convert `camelCase` names to `snake_case` keys.
  case convertToSnakeCase
}

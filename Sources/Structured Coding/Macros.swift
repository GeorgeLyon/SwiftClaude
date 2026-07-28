// MARK: - Structured Codable

@attached(
  extension,
  conformances: StructuredObject, StructuredEnumeration, StructuredObjectRepresentable,
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
    named(codingConfiguration),
    named(undeclaredPropertyBehavior)
)
public macro StructuredCodable(
  description: String? = nil,
  style: any StructuredEnumerationCodingStyle = .objectProperties,
  undeclaredPropertyBehavior: StructuredUndeclaredPropertyBehavior = .reject,
  keyConversionStrategy: StructuredCodingKeyConversionStrategy = .none,
  compatibilityMode: StructuredCodingCompatibilityMode = []
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "StructuredCodableMacro"
  )

/// Conforms a single-property struct to `StructuredWrapper`, coding it as its
/// stored value with no object container around it.
@attached(
  extension,
  conformances: StructuredWrapper,
  names:
    named(Schema),
    named(schema),
    named(StructuredObjectProperties),
    named(properties),
    named(ObjectDecoderValues),
    named(decode),
    named(init)
)
public macro StructuredCodable(
  description: String? = nil,
  style: StructuredWrapperStyle
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "StructuredCodableMacro"
  )

// MARK: - Structured Action

/// Marks a function as one of the enclosing `@StructuredTool` type's actions.
/// Actions must be declared in the tool type's body — not in an extension,
/// whose syntax cannot reveal whether the extended type is an actor (which
/// decides the generated glue's isolation).
@attached(peer)
public macro StructuredAction(
  description: String? = nil,
  inputDescription: String? = nil,
  outputDescription: String? = nil,
  keyConversionStrategy: StructuredCodingKeyConversionStrategy = .none
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "StructuredActionMacro"
  )

// MARK: - Structured Tool

/// Gathers the type's `@StructuredAction` functions into a nested
/// `Definition` container witnessing `StructuredToolProtocol`.
@attached(member, names: named(Definition), named(definition))
@attached(extension, conformances: StructuredToolProtocol)
public macro StructuredTool(
  name: String? = nil,
  description: String? = nil
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "StructuredToolMacro"
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
  /// This mode is normally *inferred*: the macro applies it automatically
  /// when the decorated type — or any type it is lexically nested in —
  /// declares a parameter pack. Spelling it explicitly is only needed when
  /// the pack is invisible to the macro, i.e. the type is declared inside an
  /// `extension` of a pack-generic type (extensions do not repeat generic
  /// parameters, and the macro only sees syntax).
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
  /// Only set this option explicitly on types whose parameter pack the macro
  /// cannot see (the extension case above); remove it entirely once the Swift
  /// runtime supports key paths rooted in pack-generic types.
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

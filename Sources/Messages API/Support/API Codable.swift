public import StructuredCoding

/// `@StructuredCodable` with Anthropic API conventions baked in: keys convert
/// to `snake_case`, and enumerations default to the internally-tagged style
/// with a `"type"` discriminator.
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
public macro APICodable(
  description: String? = nil,
  style: any StructuredEnumerationCodingStyle = .internallyTagged(discriminatorPropertyName: "type"),
  undeclaredPropertyBehavior: StructuredUndeclaredPropertyBehavior = .reject,
  keyConversionStrategy: StructuredCodingKeyConversionStrategy = .convertToSnakeCase,
  compatibilityMode: StructuredCodingCompatibilityMode = []
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "APICodableMacro"
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
public macro APICodable(
  description: String? = nil,
  style: StructuredWrapperStyle
) =
  #externalMacro(
    module: "StructuredCodingMacros",
    type: "APICodableMacro"
  )

/// The namespace the `@APICodable` macro expands its generated code against —
/// every name the expansion references is `APICodable.<Name>`, aliased here
/// onto the `StructuredCoding` implementations.
public enum APICodable {
  public typealias StructuredObject = StructuredCoding.StructuredObject
  public typealias StructuredObjectRepresentable = StructuredCoding.StructuredObjectRepresentable
  public typealias StructuredEnumeration = StructuredCoding.StructuredEnumeration
  public typealias StructuredWrapper = StructuredCoding.StructuredWrapper
  public typealias StructuredCodingSchema = StructuredCoding.StructuredCodingSchema
  public typealias StructuredObjectProperty = StructuredCoding.StructuredObjectProperty
  public typealias StructuredObjectDecoder = StructuredCoding.StructuredObjectDecoder
  public typealias StructuredRequiredObjectPropertyDefinition =
    StructuredCoding.StructuredRequiredObjectPropertyDefinition
  public typealias StructuredOptionalObjectPropertyDefinition =
    StructuredCoding.StructuredOptionalObjectPropertyDefinition
  public typealias StructuredImmutableDefaultInitializedPropertyDefinition =
    StructuredCoding.StructuredImmutableDefaultInitializedPropertyDefinition
  public typealias StructuredMutableDefaultInitializedPropertyDefinition =
    StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition
  public typealias StructuredEnumerationCase = StructuredCoding.StructuredEnumerationCase
  public typealias StructuredEmptyObject = StructuredCoding.StructuredEmptyObject
  public typealias StructuredTuple = StructuredCoding.StructuredTuple
  public typealias StructuredEnumerationCodingStyleObjectProperties =
    StructuredCoding.StructuredEnumerationCodingStyleObjectProperties
  public typealias StructuredEnumerationCodingStyleInternallyTagged =
    StructuredCoding.StructuredEnumerationCodingStyleInternallyTagged
  public typealias StructuredEnumerationCodingStyleTypeDiscriminated =
    StructuredCoding.StructuredEnumerationCodingStyleTypeDiscriminated
  public typealias StructuredEnumerationCodingConfiguration =
    StructuredCoding.StructuredEnumerationCodingConfiguration
  public typealias StructuredUndeclaredPropertyBehavior =
    StructuredCoding.StructuredUndeclaredPropertyBehavior
}

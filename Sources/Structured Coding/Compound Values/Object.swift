import JavaScriptObjectNotation
private import Synchronization

// MARK: - Object Representable

/// A marker adopted by codable types whose every encoded instance is a JSON
/// object — that, and nothing more. Consumers with a top-level-object
/// requirement (the Anthropic Messages API's tool definitions, say)
/// constrain an action's `Input` on it directly to decide whether the
/// input's schema can stand as a tool's input schema or must travel inside
/// an envelope object. `StructuredObject` refines it, and
/// `@StructuredCodable` adds it to enumerations whose coding style always
/// encodes an object (the object-properties and internally-tagged styles;
/// not type-discriminated, whose values encode as bare payloads). Adopt it
/// by hand only on a type whose `encode(to:)` unconditionally produces a
/// JSON object — the promise is not compiler-checked.
public protocol StructuredObjectRepresentable {}

// MARK: - Definition

public protocol StructuredObject: StructuredCodable, StructuredObjectRepresentable {

  associatedtype StructuredObjectProperties
  static func properties() -> StructuredObjectProperties

  associatedtype ObjectDecoderValues
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  static func decodeProperties<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredObjectPropertiesDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor,
    configuration: some StructuredObjectPropertiesDecodingConfiguration
  ) async throws
  where
    Accessor.Value == Self

  func encodeProperties(
    to encoder: inout StructuredObjectPropertiesEncoder
  ) throws

}

// MARK: Structured Object Decoder

public struct StructuredObjectDecoder<Values> {
  public let values: Values
}

// MARK: Empty Object

@StructuredCodable
public struct StructuredEmptyObject {

}

// MARK: Property

/// Properties vary across a few axes:
/// - Mutability (let vs var)
/// - Optionality
/// - Presence of a default initializer
extension StructuredObjectProperty {
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: KeyPath<Root, T> & Sendable,
    schema: T.Schema
  ) where Definition == StructuredRequiredObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .getOnly(keyPath)
    self.definition = Definition(name: name)
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: KeyPath<Root, T?> & Sendable,
    schema: T.Schema
  ) where Definition == StructuredOptionalObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .getOnly(keyPath)
    self.definition = Definition()
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    getter: @escaping @Sendable (Root) -> T,
    schema: T.Schema
  ) where Definition == StructuredRequiredObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .getOnlyClosure(getter)
    self.definition = Definition(name: name)
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    getter: @escaping @Sendable (Root) -> T?,
    schema: T.Schema
  ) where Definition == StructuredOptionalObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .getOnlyClosure(getter)
    self.definition = Definition()
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: WritableKeyPath<Root, T> & Sendable,
    schema: T.Schema
  ) where Definition == StructuredRequiredObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .writable(keyPath)
    self.definition = Definition(name: name)
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: WritableKeyPath<Root, T?> & Sendable,
    schema: T.Schema
  ) where Definition == StructuredOptionalObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .writable(keyPath)
    self.definition = Definition()
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: ReferenceWritableKeyPath<Root, T> & Sendable,
    schema: T.Schema
  ) where Definition == StructuredRequiredObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .referenceWritable(keyPath)
    self.definition = Definition(name: name)
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: ReferenceWritableKeyPath<Root, T?> & Sendable,
    schema: T.Schema
  ) where Definition == StructuredOptionalObjectPropertyDefinition<T> {
    self.name = name
    self.taggedKeyPath = .referenceWritable(keyPath)
    self.definition = Definition()
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: KeyPath<Root, T> & Sendable,
    schema: T.Schema,
  )
  where
    Definition == StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .getOnly(keyPath)
    self.definition = Definition(name: name, base: .init(name: name))
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: KeyPath<Root, T?> & Sendable,
    schema: T.Schema,
  )
  where
    Definition == StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredOptionalObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .getOnly(keyPath)
    self.definition = Definition(name: name, base: .init())
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    getter: @escaping @Sendable (Root) -> T,
    schema: T.Schema,
  )
  where
    Definition == StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .getOnlyClosure(getter)
    self.definition = Definition(name: name, base: .init(name: name))
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    getter: @escaping @Sendable (Root) -> T?,
    schema: T.Schema,
  )
  where
    Definition == StructuredImmutableDefaultInitializedPropertyDefinition<
      StructuredOptionalObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .getOnlyClosure(getter)
    self.definition = Definition(name: name, base: .init())
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: WritableKeyPath<Root, T> & Sendable,
    schema: T.Schema,
  )
  where
    Definition == StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .writable(keyPath)
    self.definition = Definition(base: .init(name: name))
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: WritableKeyPath<Root, T?> & Sendable,
    schema: T.Schema,
  )
  where
    Definition == StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredOptionalObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .writable(keyPath)
    self.definition = Definition(base: .init())
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: ReferenceWritableKeyPath<Root, T> & Sendable,
    schema: T.Schema,
  )
  where
    Definition == StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .referenceWritable(keyPath)
    self.definition = Definition(base: .init(name: name))
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    keyPath: ReferenceWritableKeyPath<Root, T?> & Sendable,
    schema: T.Schema,
  )
  where
    Definition == StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredOptionalObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .referenceWritable(keyPath)
    self.definition = Definition(base: .init())
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    getter: @escaping @Sendable (Root) -> T,
    schema: T.Schema,
  )
  where
    Definition == StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredRequiredObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .getOnlyClosure(getter)
    self.definition = Definition(base: .init(name: name))
    self.schema = schema.prependDescription(description)
  }
  public init<T>(
    name: StructuredCodingKey,
    description: String? = nil,
    getter: @escaping @Sendable (Root) -> T?,
    schema: T.Schema,
  )
  where
    Definition == StructuredMutableDefaultInitializedPropertyDefinition<
      StructuredOptionalObjectPropertyDefinition<T>
    >
  {
    self.name = name
    self.taggedKeyPath = .getOnlyClosure(getter)
    self.definition = Definition(base: .init())
    self.schema = schema.prependDescription(description)
  }
}

public struct StructuredObjectProperty<Root, _Definition: StructuredObjectPropertyDefinition> {
  public typealias Definition = _Definition
  public typealias ObjectDecoderValue = Definition.ObjectDecoderValue
  public typealias CodingSchema = Definition.CodingValue.Schema
  let name: StructuredCodingKey
  let schema: CodingSchema
  var isRequired: Bool { definition.isRequired }
  let taggedKeyPath: TaggedKeyPath<Root, Definition.PropertyValue>
  let definition: Definition
}

/// How a type behaves as a `StructuredObject` property. The
/// `@StructuredCodable` macro references this through the declared property
/// type, so the *resolved* type decides — `typealias Foo = Bar?` lowers
/// exactly like `Bar?`, something the macro could never determine from
/// syntax alone. Deliberately a plain member typealias rather than an
/// associated-type witness: the macro only ever spells it on concrete types,
/// and a witness would force decode-only types (which cannot satisfy the
/// required-property default) to provide one even though they never appear
/// as object properties.
extension StructuredDecodable where Self: StructuredEncodable {

  /// The default object-property behavior: a required property.
  public typealias _StructuredObjectPropertyDefinition =
    StructuredRequiredObjectPropertyDefinition<Self>

}

/// As an object property, `nil` is expressed by omitting the property — not
/// by `Optional`'s own `{}`/`{"value":…}` coding.
extension Optional where Wrapped: StructuredCodable {

  public typealias _StructuredObjectPropertyDefinition =
    StructuredOptionalObjectPropertyDefinition<Wrapped>

}

public protocol StructuredObjectPropertyDefinition: SendableMetatype {
  /// The type of this property on a constructed object
  associatedtype PropertyValue

  /// The value of this property when it is coded
  /// For an optional, this will be `Wrapped`
  associatedtype CodingValue: StructuredCodable

  /// The type of value we use during initialization
  /// Default-initialized properties use `Void` when immutable and `PropertyValue?` when mutable
  associatedtype ObjectDecoderValue = PropertyValue

  /// The type that is used to validate the property after streaming has completed
  /// This is `PropertyValue` for immutable default-initialized properties
  associatedtype ValidationPayload = Void

  var isRequired: Bool { get }

  func encode(
    _ propertyValue: PropertyValue,
    forKey name: StructuredCodingKey,
    in encoder: inout StructuredObjectPropertiesEncoder
  ) throws

  func initialValueForDecoding(
    isMutable: Bool
  ) -> sending StructuredObjectPropertyDecodingValue<PropertyValue, ObjectDecoderValue>
  func objectDecoderValue(
    from propertyValue: sending PropertyValue
  ) -> sending ObjectDecoderValue
  func decodeValue<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == PropertyValue
  func decodeOmitted<Accessor: StructuredAccessor & ~Escapable>(
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == PropertyValue
  func validate<Accessor: StructuredAccessor & ~Escapable>(
    _ payload: sending ValidationPayload,
    using accessor: borrowing Accessor
  ) async throws
  where Accessor.Value == PropertyValue
}

public struct StructuredObjectPropertyDecodingValue<PropertyValue, ObjectDecoderValue> {
  enum Kind {
    case propertyValue(PropertyValue)
    case objectDecoderValue(ObjectDecoderValue)
  }
  let kind: Kind?
}

public struct StructuredRequiredObjectPropertyDefinition<
  Value: StructuredCodable
>: StructuredObjectPropertyDefinition {

  public typealias PropertyValue = Value
  public typealias CodingValue = Value

  public var isRequired: Bool { true }

  public func encode(
    _ propertyValue: PropertyValue,
    forKey name: StructuredCodingKey,
    in encoder: inout StructuredObjectPropertiesEncoder
  ) throws {
    try encoder.encodeProperty(named: name) { encoder in
      try propertyValue.encode(to: &encoder)
    }
  }

  public func initialValueForDecoding(
    isMutable: Bool
  ) -> sending StructuredObjectPropertyDecodingValue<PropertyValue, PropertyValue> {
    StructuredObjectPropertyDecodingValue(
      kind:
        PropertyValue
        .initialValueForDecoding(isMutable: isMutable)
        .map { .propertyValue($0) }
    )
  }

  public func objectDecoderValue(
    from propertyValue: sending PropertyValue
  ) -> sending ObjectDecoderValue {
    propertyValue
  }

  public func decodeValue<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending Void where Accessor.Value == PropertyValue {
    try await PropertyValue.decode(from: &decoder, in: context, using: accessor)
  }

  public func decodeOmitted<Accessor: StructuredAccessor & ~Escapable>(
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == PropertyValue {
    throw ObjectDecodingError.propertyNotFound(name.stringValue)
  }

  public func validate<Accessor: StructuredAccessor & ~Escapable>(
    _ payload: sending (),
    using accessor: borrowing Accessor
  ) async throws where Accessor.Value == PropertyValue {
    /// No validation
  }

  fileprivate let name: StructuredCodingKey

}

public struct StructuredOptionalObjectPropertyDefinition<
  Wrapped: StructuredCodable
>: StructuredObjectPropertyDefinition {

  public typealias PropertyValue = Wrapped?
  public typealias CodingValue = Wrapped

  public var isRequired: Bool { false }

  public func encode(
    _ propertyValue: Wrapped?,
    forKey name: StructuredCodingKey,
    in encoder: inout StructuredObjectPropertiesEncoder
  ) throws {
    guard let propertyValue else { return }
    try encoder.encodeProperty(named: name) { encoder in
      try propertyValue.encode(to: &encoder)
    }
  }

  public func initialValueForDecoding(
    isMutable: Bool
  ) -> sending StructuredObjectPropertyDecodingValue<Wrapped?, Wrapped?> {
    StructuredObjectPropertyDecodingValue(
      kind: isMutable ? .propertyValue(nil) : nil
    )
  }
  public func objectDecoderValue(
    from propertyValue: sending PropertyValue
  ) -> sending ObjectDecoderValue {
    propertyValue
  }
  public func decodeValue<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending Void where Accessor.Value == Wrapped? {
    if let initialValue = Wrapped.initialValueForDecoding(isMutable: accessor.isMutable) {
      try await accessor.initializeValue(to: initialValue)
    }
    return try await accessor.withSomeAccessor { accessor in
      try await Wrapped.decode(from: &decoder, in: context, using: accessor)
    }
  }
  public func decodeOmitted<Accessor: StructuredAccessor & ~Escapable>(
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == PropertyValue {
    try await accessor.initializeValue(to: nil)
  }
  public func validate<Accessor: StructuredAccessor & ~Escapable>(
    _ payload: sending (),
    using accessor: borrowing Accessor
  ) async throws where Accessor.Value == Wrapped? {
    // No validation
  }
}

public struct StructuredImmutableDefaultInitializedPropertyDefinition<
  Base: StructuredObjectPropertyDefinition
>: StructuredObjectPropertyDefinition
where
  Base.ObjectDecoderValue == Base.PropertyValue,
  Base.PropertyValue: Equatable & SendableMetatype,
  Base.ValidationPayload == Void
{
  public typealias PropertyValue = Base.PropertyValue
  public typealias CodingValue = Base.CodingValue
  public typealias ObjectDecoderValue = Void
  public typealias ValidationPayload = PropertyValue

  public var isRequired: Bool { base.isRequired }

  public func encode(
    _ propertyValue: Base.PropertyValue,
    forKey name: StructuredCodingKey,
    in encoder: inout StructuredObjectPropertiesEncoder
  ) throws {
    try base.encode(propertyValue, forKey: name, in: &encoder)
  }

  public func initialValueForDecoding(
    isMutable: Bool
  ) -> sending StructuredObjectPropertyDecodingValue<Base.PropertyValue, Void> {
    StructuredObjectPropertyDecodingValue(kind: .objectDecoderValue(()))
  }
  public func objectDecoderValue(
    from propertyValue: sending PropertyValue
  ) -> sending ObjectDecoderValue {
    ()
  }
  public func decodeValue<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == PropertyValue {
    try await context.withArena { arena in
      try await withSendingAccessor(in: arena) { accessor in
        switch base.initialValueForDecoding(isMutable: accessor.isMutable).kind {
        case .propertyValue(let value):
          try await accessor.initializeValue(to: value)
        case .objectDecoderValue, .none:
          break
        }
        try await base.decodeValue(from: &decoder, in: context, using: accessor)
      }
    }
  }
  public func decodeOmitted<Accessor: StructuredAccessor & ~Escapable>(
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == PropertyValue {
    try await context.withArena { arena in
      try await withSendingAccessor(in: arena) { accessor in
        try await base.decodeOmitted(in: context, using: accessor)
      }
    }
  }
  public func validate<Accessor: StructuredAccessor & ~Escapable>(
    _ payload: sending Base.PropertyValue,
    using accessor: borrowing Accessor
  ) async throws where Accessor.Value == PropertyValue {
    let name = self.name
    try await accessor.accessValue(applying: payload) { value, expectedValue in
      guard value == expectedValue else {
        throw ObjectDecodingError.constantPropertyValueMismatch(name.stringValue)
      }
    }
  }
  fileprivate let name: StructuredCodingKey
  fileprivate let base: Base
}

public struct StructuredMutableDefaultInitializedPropertyDefinition<
  Base: StructuredObjectPropertyDefinition
>: StructuredObjectPropertyDefinition
where
  Base.ValidationPayload == Void,
  Base.ObjectDecoderValue == Base.PropertyValue
{

  public typealias PropertyValue = Base.PropertyValue
  public typealias CodingValue = Base.CodingValue
  public typealias ObjectDecoderValue = PropertyValue?
  public typealias ValidationPayload = Void

  public var isRequired: Bool { base.isRequired }

  public func encode(
    _ propertyValue: Base.PropertyValue,
    forKey name: StructuredCodingKey,
    in encoder: inout StructuredObjectPropertiesEncoder
  ) throws {
    try base.encode(propertyValue, forKey: name, in: &encoder)
  }

  public func initialValueForDecoding(
    isMutable: Bool
  ) -> sending StructuredObjectPropertyDecodingValue<Base.PropertyValue, PropertyValue?> {
    let kind: StructuredObjectPropertyDecodingValue<Base.PropertyValue, PropertyValue?>.Kind? =
      if isMutable {
        .objectDecoderValue(nil)
      } else {
        switch base.initialValueForDecoding(isMutable: isMutable).kind {
        case .none:
          .none
        case .objectDecoderValue(let value), .propertyValue(let value):
          .propertyValue(value)
        }
      }
    return StructuredObjectPropertyDecodingValue(kind: kind)
  }
  public func objectDecoderValue(
    from propertyValue: sending PropertyValue
  ) -> sending ObjectDecoderValue {
    propertyValue
  }
  public func decodeValue<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == Base.PropertyValue {
    if accessor.isMutable {
      /// In `initialValueForDecoding` we instructed the system to use the default-initialized value so we need to reinitialize it to the expected value.
      switch base.initialValueForDecoding(isMutable: true).kind {
      case .none:
        break
      case .objectDecoderValue(let value), .propertyValue(let value):
        try await accessor.initializeValue(to: value)
      }
    }
    return try await base.decodeValue(from: &decoder, in: context, using: accessor)
  }
  public func decodeOmitted<Accessor: StructuredAccessor & ~Escapable>(
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws -> sending ValidationPayload
  where Accessor.Value == PropertyValue {
    if accessor.isMutable {
      let value = try await context.withArena { arena in
        try await withSendingAccessor(in: arena) { accessor in
          try await base.decodeOmitted(in: context, using: accessor)
        }
      }
      try await accessor.initializeValue(to: value)
    } else {
      try await base.decodeOmitted(in: context, using: accessor)
    }
  }

  public func validate<Accessor: StructuredAccessor & ~Escapable>(
    _ payload: sending ValidationPayload,
    using accessor: borrowing Accessor
  ) async throws where Accessor.Value == PropertyValue {
    try await base.validate(payload, using: accessor)
  }

  fileprivate let base: Base
}

// MARK: - Schema

extension StructuredObject {

  /// The shared implementation behind every object's `schema` witness. The
  /// witness itself must be a non-generic member of the concrete type (the
  /// `@StructuredCodable` macro generates a trampoline calling this function):
  /// an opaque result type on a generic function cannot infer the `Schema`
  /// associated type.
  ///
  /// `typeDescription` is the type's own `@StructuredCodable(description:)`,
  /// passed by the generated trampoline; use-site descriptions are prepended
  /// onto the returned schema with `prependDescription(_:)`.
  public static func _schema<each PropertyDefinition>(
    typeDescription: String? = nil
  ) -> some StructuredCodingSchema
  where
    StructuredObjectProperties == (
      repeat StructuredObjectProperty<Self, each PropertyDefinition>
    )
  {
    let properties = self.properties()
    return MetaSchema.object(
      description: typeDescription,
      properties: repeat (
        (each properties).name,
        (each properties).schema,
        (each properties).isRequired
      )
    )
  }

}

// MARK: - Encoding

public struct StructuredObjectPropertiesEncoder: ~Copyable {

  public mutating func encodeProperty(
    named name: StructuredCodingKey,
    _ encodeValue: (inout StructuredEncoder) throws -> Void
  ) rethrows {
    try objectEncoder.encodeProperty(
      encodeName: { stream in
        stream.encode(name.staticStringValue)
      },
      encodeValue: { stream in
        try stream.withEncoder(encodeValue)
      }
    )
  }

  fileprivate init(objectEncoder: consuming EncodingStream.ObjectEncoder) {
    self.objectEncoder = objectEncoder
  }

  fileprivate consuming func finish() -> EncodingStream.ObjectEncoder {
    objectEncoder
  }

  private var objectEncoder: EncodingStream.ObjectEncoder

}

extension EncodingStream.ObjectEncoder {

  mutating func withPropertiesEncoder<T>(
    _ body: (inout StructuredObjectPropertiesEncoder) throws -> T
  ) rethrows -> T {
    var propertiesEncoder = StructuredObjectPropertiesEncoder(objectEncoder: self)
    do {
      let result = try body(&propertiesEncoder)
      self = propertiesEncoder.finish()
      return result
    } catch {
      self = propertiesEncoder.finish()
      throw error
    }
  }

}

extension StructuredObject {

  public func encode<each PropertyDefinition>(
    to encoder: inout StructuredEncoder
  ) throws
  where
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>)
  {
    try encoder.stream.encodeObject { objectEncoder in
      try objectEncoder.withPropertiesEncoder { propertiesEncoder in
        try encodeProperties(to: &propertiesEncoder)
      }
    }
  }

  public func encodeProperties<each PropertyDefinition>(
    to encoder: inout StructuredObjectPropertiesEncoder
  ) throws
  where
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>)
  {
    let propertiesTuple = Self.properties()
    let properties = (repeat each propertiesTuple)
    for property in repeat (each properties) {
      let propertyValue = property.taggedKeyPath.accessValue(on: self)
      try property.definition.encode(propertyValue, forKey: property.name, in: &encoder)
    }
  }

}

// MARK: - Decoding

extension StructuredObject {

  public static func initialValueForDecoding<each PropertyDefinition>(
    isMutable isBaseMutable: Bool
  ) -> sending Self?
  where
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    ObjectDecoderValues == (repeat (each PropertyDefinition).ObjectDecoderValue)
  {
    func initialObjectDecoderValue<Definition: StructuredObjectPropertyDefinition>(
      for property: StructuredObjectProperty<Self, Definition>
    ) throws(ObjectInitialValueError) -> sending Definition.ObjectDecoderValue {
      let isMutable =
        switch property.taggedKeyPath {
        case .getOnly, .getOnlyClosure:
          false
        case .writable:
          isBaseMutable
        case .referenceWritable:
          true
        }
      switch property.definition.initialValueForDecoding(isMutable: isMutable).kind {
      case .none:
        throw ObjectInitialValueError.propertyHasNoInitialValue
      case .propertyValue(let value):
        return property.definition.objectDecoderValue(from: value)
      case .objectDecoderValue(let value):
        return value
      }
    }
    let properties = (repeat each properties())
    do {
      let objectDecoder = StructuredObjectDecoder(
        values: (repeat try initialObjectDecoderValue(for: each properties))
      )
      return Self.decode(from: objectDecoder)
    } catch {
      switch error {
      case .propertyHasNoInitialValue:
        return nil
      }
    }
  }

  public static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each PropertyDefinition
  >(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor,
  ) async throws
  where
    Accessor.Value == Self,
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    ObjectDecoderValues == (repeat (each PropertyDefinition).ObjectDecoderValue)
  {
    try await context.withArena { arena in
      try await decoder.stream.decodeObjectProperties(in: arena) { propertiesDecoder in
        try await decodeProperties(
          from: &propertiesDecoder,
          in: context,
          using: accessor,
          configuration: DefaultObjectPropertiesDecodingConfiguration()
        )
      }
    }
  }

  public static func decodeProperties<
    Accessor: StructuredAccessor & ~Escapable,
    each PropertyDefinition
  >(
    from decoder: inout StructuredObjectPropertiesDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor,
    configuration: some StructuredObjectPropertiesDecodingConfiguration
  ) async throws
  where
    Accessor.Value == Self,
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    ObjectDecoderValues == (repeat (each PropertyDefinition).ObjectDecoderValue)
  {
    let properties = (repeat each properties())
    try await context.withArena { arena in
      if initialValueForDecoding(isMutable: accessor.isMutable) != nil {
        try await decodeStreamed(
          properties: (repeat each properties),
          propertiesDecoder: &decoder,
          in: context,
          using: accessor,
          arena: arena,
          configuration: configuration
        )
      } else {
        try await decodeBuffered(
          properties: (repeat each properties),
          propertiesDecoder: &decoder,
          in: context,
          using: accessor,
          arena: arena,
          configuration: configuration
        )
      }
    }
  }

  /// Decodes an object whose properties can all be initialized up front, streaming each decoded
  /// value into place as it arrives.
  private static func decodeStreamed<
    Accessor: StructuredAccessor & ~Escapable,
    each PropertyDefinition
  >(
    properties: (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    propertiesDecoder: inout StructuredObjectPropertiesDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor,
    arena: borrowing Arena,
    configuration: some StructuredObjectPropertiesDecodingConfiguration
  ) async throws
  where
    Accessor.Value == Self,
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    ObjectDecoderValues == (repeat (each PropertyDefinition).ObjectDecoderValue)
  {
    let configurationState = configuration.prepareForDecoding(from: &propertiesDecoder)

    let checkpoints =
      (repeat propertiesDecoder.createCheckpoint((each PropertyDefinition).self))
    let stateRefs =
      (repeat arena.push(ObjectPropertyStreamedDecodingState(each properties)).unsafePointer)

    outer: while propertiesDecoder.shouldContinueDecoding() {
      try await configuration.decodeAdditionalProperties(
        from: &propertiesDecoder,
        with: configurationState
      )
      for (property, checkpoint, stateRef) in repeat (
        each properties, each checkpoints, each stateRefs
      ) {
        try await propertiesDecoder.decodeIfNextPropertyNamed(
          property.name.stringValue,
          checkpoint: checkpoint,
          decode: { stream in
            if stateRef.pointee.isDecoded {
              throw ObjectDecodingError.duplicateProperty(property.name.stringValue)
            }
            let validationPayload = try await stream.withDecoder { decoder in
              try await property.definition.decodeValue(
                from: &decoder,
                in: context,
                using: KeyPathAccessor(
                  base: accessor,
                  keyPath: property.taggedKeyPath
                )
              )
            }
            stateRef.pointee = .decoded(Sending(validationPayload))
          }
        )
        if propertiesDecoder.isAtEnd {
          break outer
        }
      }
    }

    try propertiesDecoder.finishDecoding()

    for (property, stateRef) in repeat (each properties, each stateRefs) {
      try await stateRef.pointee.finishDecoding(for: property, in: context, using: accessor)
    }

    for (property, stateRef) in repeat (each properties, each stateRefs) {
      let accessor = KeyPathAccessor(
        base: accessor,
        keyPath: property.taggedKeyPath
      )
      let payload = try await stateRef.pointee.validate(for: property)
      try await property.definition.validate(payload, using: accessor)
    }
  }

  /// Decodes an object that has at least one property without an initial value, buffering decoded
  /// values until the object can be created, then streaming any remaining values into place.
  private static func decodeBuffered<
    Accessor: StructuredAccessor & ~Escapable,
    each PropertyDefinition
  >(
    properties: (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    propertiesDecoder: inout StructuredObjectPropertiesDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor,
    arena: borrowing Arena,
    configuration: some StructuredObjectPropertiesDecodingConfiguration
  ) async throws
  where
    Accessor.Value == Self,
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    ObjectDecoderValues == (repeat (each PropertyDefinition).ObjectDecoderValue)
  {
    let configurationState = configuration.prepareForDecoding(from: &propertiesDecoder)

    let checkpoints =
      (repeat propertiesDecoder.createCheckpoint((each PropertyDefinition).self))
    let stateRefs =
      (repeat arena.push(
        ObjectPropertyBufferedDecodingState(
          property: each properties,
          accessor: accessor
        )
      ).unsafePointer)

    var unavailablePropertyCount = 0
    for stateRef in repeat each stateRefs {
      if stateRef.pointee.isUnavailable {
        unavailablePropertyCount += 1
      }
    }

    if unavailablePropertyCount == 0 {
      /// If `unavailablePropertyCount` == 0 we should provide an `initialValue` and use the streaming codepath.
      assertionFailure()
      try await decode(from: repeat each stateRefs, using: accessor)
    }

    outer: while propertiesDecoder.shouldContinueDecoding() {
      try await configuration.decodeAdditionalProperties(
        from: &propertiesDecoder,
        with: configurationState
      )
      for (property, checkpoint, stateRef) in repeat (
        each properties, each checkpoints, each stateRefs
      ) {
        try await propertiesDecoder.decodeIfNextPropertyNamed(
          property.name.stringValue,
          checkpoint: checkpoint,
          decode: { stream in
            if stateRef.pointee.isDecoded {
              throw ObjectDecodingError.duplicateProperty(property.name.stringValue)
            }
            try await stream.withDecoder { decoder in
              if unavailablePropertyCount == 0 {
                let validationPayload = try await property.definition.decodeValue(
                  from: &decoder,
                  in: context,
                  using: KeyPathAccessor(
                    base: accessor,
                    keyPath: property.taggedKeyPath
                  )
                )
                stateRef.pointee = .streaming(.decoded(Sending(validationPayload)))
              } else if unavailablePropertyCount == 1, stateRef.pointee.isUnavailable {
                let validationPayload = try await property.definition.decodeValue(
                  from: &decoder,
                  in: context,
                  using: InitializingAccessor(
                    arena: copy arena,
                    streamingProperty: property,
                    streamingStateRef: stateRef,
                    bufferingStateRefs: (repeat each stateRefs),
                    base: accessor
                  )
                )
                stateRef.pointee = .streaming(.decoded(Sending(validationPayload)))
                unavailablePropertyCount = 0
              } else {
                if stateRef.pointee.isUnavailable {
                  unavailablePropertyCount -= 1
                }
                let validationPayload = try await property.definition.decodeValue(
                  from: &decoder,
                  in: context,
                  using: PreInitializationAccessor(stateRef: stateRef)
                )
                try stateRef.pointee.finishDecodingToBuffer(for: property, with: validationPayload)
              }
            }
          }
        )
        if propertiesDecoder.isAtEnd {
          break outer
        }
      }
    }

    try propertiesDecoder.finishDecoding()

    for (property, stateRef) in repeat (each properties, each stateRefs) {
      try await stateRef.pointee.finishDecoding(for: property, in: context, using: accessor)
    }

    if unavailablePropertyCount > 0 {
      /// The object wasn't initialized during streaming
      try await decode(from: repeat each stateRefs, using: accessor)
    }

    for (property, stateRef) in repeat (each properties, each stateRefs) {
      let accessor = KeyPathAccessor(
        base: accessor,
        keyPath: property.taggedKeyPath
      )
      let payload = try await stateRef.pointee.validate(for: property)
      try await property.definition.validate(payload, using: accessor)
    }
  }

  private static func propertyCount<each PropertyDefinition>() -> Int
  where StructuredObjectProperties == (repeat each PropertyDefinition) {
    var count = 0
    for _ in repeat each properties() {
      count += 1
    }
    return count
  }

  fileprivate static func decode<
    Accessor: StructuredAccessor & ~Escapable,
    each PropertyDefinition
  >(
    from stateRefs: repeat UnsafeMutablePointer<
      ObjectPropertyBufferedDecodingState<Self, each PropertyDefinition>
    >,
    using accessor: Accessor
  ) async throws
  where
    Accessor.Value == Self,
    StructuredObjectProperties == (repeat StructuredObjectProperty<Self, each PropertyDefinition>),
    ObjectDecoderValues == (repeat (each PropertyDefinition).ObjectDecoderValue)
  {
    let objectDecoder = StructuredObjectDecoder(
      values: (repeat (each stateRefs).pointee.beginStreaming(
        for: each properties()
      ))
    )
    try await accessor.initializeValue(to: Self.decode(from: objectDecoder))
  }

}

private enum ObjectInitialValueError: Error {
  case propertyHasNoInitialValue
}

private enum ObjectDecodingError: Error {
  case unknownProperty(String)
  case duplicateProperty(String)
  case propertyNotFound(String)
  case constantPropertyValueMismatch(String)
  case invalidState
}

// MARK: Property Decoding

public protocol StructuredObjectPropertiesDecodingConfiguration {
  associatedtype DecodingState
  func prepareForDecoding(from decoder: inout StructuredObjectPropertiesDecoder) -> DecodingState
  func decodeAdditionalProperties(
    from decoder: inout StructuredObjectPropertiesDecoder,
    with state: DecodingState
  ) async throws
}

private struct DefaultObjectPropertiesDecodingConfiguration:
  StructuredObjectPropertiesDecodingConfiguration
{
  func prepareForDecoding(from decoder: inout StructuredObjectPropertiesDecoder) {
  }
  func decodeAdditionalProperties(
    from decoder: inout StructuredObjectPropertiesDecoder,
    with state: Void
  ) async throws {
  }
}

public struct StructuredObjectPropertiesDecoder: ~Copyable, ~Escapable {

  /// Generic so we can make a pack of it
  struct Checkpoint<T> {
    fileprivate var value: Int
  }

  @_lifetime(&objectDecoder, copy arena)
  fileprivate init(
    firstPropertyName: String?,
    objectDecoder: inout DecodingStream.ObjectDecoder,
    arena: borrowing Arena
  ) {
    self.objectDecoder = objectDecoder.mutate()
    self._propertyName = arena.push(firstPropertyName)
    self._nextCheckpoint = arena.push(Self.firstCheckpoint.value + 1)
    self._terminationCheckpoint = arena.push(nil)
  }

  var isAtEnd: Bool {
    objectDecoder.isAtEnd
  }

  /// The name of the property currently positioned for decoding, or `nil` when
  /// the object has no further properties to decode.
  var currentPropertyName: String? {
    propertyName
  }

  mutating func shouldContinueDecoding() -> Bool {
    shouldContinue(from: Self.firstCheckpoint)
  }

  mutating func createCheckpoint<T>(_ markerType: T.Type = T.self) -> Checkpoint<T> {
    defer { nextCheckpoint += 1 }
    return Checkpoint(value: nextCheckpoint)
  }

  /// This API is a little unhinged, but can be simplified once non-escapable types can live in parameter packs.
  mutating func decodeIfNextPropertyNamed<T>(
    _ name: String,
    checkpoint: Checkpoint<T>,
    decode: (inout DecodingStream) async throws -> Void
  ) async throws {
    guard let propertyName else {
      return
    }
    guard propertyName == name else {
      guard shouldContinue(from: checkpoint) else {
        throw ObjectDecodingError.unknownProperty(propertyName)
      }
      return
    }
    terminationCheckpoint = nil

    try await decode(&objectDecoder.stream)

    try await objectDecoder.finishDecodingProperty()
    if objectDecoder.isAtEnd {
      self.propertyName = nil
    } else {
      let propertyName = try await objectDecoder.startDecodingProperty()
      self.propertyName = propertyName
    }
  }

  func finishDecoding() throws {
    if let propertyName {
      throw ObjectDecodingError.unknownProperty(propertyName)
    }
  }

  private mutating func shouldContinue<T>(from checkpoint: Checkpoint<T>) -> Bool {
    if let terminationCheckpoint {
      return terminationCheckpoint != checkpoint.value
    } else {
      terminationCheckpoint = checkpoint.value
      return true
    }
  }

  private(set) var objectDecoder: DecodingStream.ObjectDecoder

  @ArenaRef private var terminationCheckpoint: Int?
  @ArenaRef private var nextCheckpoint: Int
  @ArenaRef private var propertyName: String?

  private static let firstCheckpoint = Checkpoint<Void>(value: 0)

}

extension DecodingStream {

  mutating func decodeObjectProperties(
    in arena: borrowing Arena,
    _ body: (inout StructuredObjectPropertiesDecoder) async throws -> Void
  ) async throws {
    try await decodeObject { objectDecoder in
      try await objectDecoder.decodeObjectProperties(in: arena, body)
    }
  }

}

extension DecodingStream.ObjectDecoder {

  mutating func decodeObjectProperties(
    in arena: borrowing Arena,
    _ body: (inout StructuredObjectPropertiesDecoder) async throws -> Void
  ) async throws {
    let firstPropertyName: String? =
      if self.isAtEnd {
        nil
      } else {
        try await self.startDecodingProperty()
      }
    var propertiesDecoder = StructuredObjectPropertiesDecoder(
      firstPropertyName: firstPropertyName,
      objectDecoder: &self,
      arena: arena
    )
    do {
      try await body(&propertiesDecoder)
      self = propertiesDecoder.objectDecoder
    } catch {
      self = propertiesDecoder.objectDecoder
      throw error
    }
  }

}

// MARK: Property Decoding States

private enum ObjectPropertyBufferedDecodingState<
  Root, Definition: StructuredObjectPropertyDefinition
>: ~Copyable {

  init<Accessor: StructuredAccessor & ~Escapable>(
    property: StructuredObjectProperty<Root, Definition>,
    accessor: Accessor
  ) where Accessor.Value == Root {
    let derivedAccessor = KeyPathAccessor(
      base: accessor,
      keyPath: property.taggedKeyPath
    )
    switch property.definition.initialValueForDecoding(isMutable: derivedAccessor.isMutable).kind {
    case .none:
      self = .unavailable
    case .objectDecoderValue(let value):
      self = .seeded(Sending(value))
    case .propertyValue(let value):
      self = .available(Sending(value))
    }
  }

  /// The property value is unavailable
  case unavailable

  /// The property value is unavailable, but we have a seed we can use for object initialization
  case seeded(Sending<Definition.ObjectDecoderValue>)

  /// A value property value is available to create the object
  case available(Sending<Definition.PropertyValue>)

  /// The property has been decoded and is available to create the object
  case decoded(Sending<Definition.ObjectDecoderValue>, Sending<Definition.ValidationPayload>)

  /// The object has been created and we can stream the value in-place
  case streaming(ObjectPropertyStreamedDecodingState<Root, Definition>)

  var isUnavailable: Bool {
    switch self {
    case .unavailable: true
    case .seeded: false
    case .available: false
    case .decoded: fatalError()
    case .streaming: fatalError()
    }
  }

  var isDecoded: Bool {
    switch self {
    case .unavailable: false
    case .seeded: false
    case .available: false
    case .decoded: true
    case .streaming(let streamingState): streamingState.isDecoded
    }
  }

  mutating func apply<Delta, T>(
    _ delta: sending Delta,
    with body: @Sendable (inout Definition.PropertyValue, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    switch consume self {
    case .unavailable:
      self = .unavailable
      throw AccessorError.uninitializedValue
    case .seeded(let seed):
      self = .seeded(seed)
      throw AccessorError.uninitializedValue
    case .available(var value):
      do {
        let result = try await value.apply(delta, with: body)
        self = .available(value)
        return result
      } catch {
        self = .available(value)
        throw error
      }
    case .streaming: fatalError()
    case .decoded: fatalError()
    }
  }

  mutating func finishDecodingToBuffer(
    for property: StructuredObjectProperty<Root, Definition>,
    with validationPayload: sending Definition.ValidationPayload
  ) throws {
    switch consume self {
    case .unavailable:
      self = .unavailable
      throw AccessorError.uninitializedValue
    case .seeded(let seed):
      self = .decoded(seed, Sending(validationPayload))
    case .available(let value):
      self = .decoded(
        Sending(property.definition.objectDecoderValue(from: value.send())),
        Sending(validationPayload)
      )
    case .decoded:
      fatalError()
    case .streaming:
      fatalError()
    }
  }

  mutating func finishDecoding<Accessor: StructuredAccessor & ~Escapable>(
    for property: StructuredObjectProperty<Root, Definition>,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where Accessor.Value == Root {
    func omittedState() async throws -> Self {
      let pair = try await withSendingAccessor(
        in: context,
        sending: (),
        to: { accessor, _ in
          try await property.definition.decodeOmitted(in: context, using: accessor)
        },
        merge: { value, validationPayload in
          Pair(
            first: Sending(value),
            second: Sending(validationPayload)
          )
        }
      )
      return .decoded(
        Sending(property.definition.objectDecoderValue(from: pair.first.send())),
        pair.second
      )
    }
    switch consume self {
    case .unavailable:
      do {
        self = try await omittedState()
      } catch {
        self = .unavailable
        throw error
      }
    case .seeded(let value):
      do {
        self = try await omittedState()
      } catch {
        self = .seeded(value)
        throw error
      }
    case .available(let value):
      do {
        self = try await omittedState()
      } catch {
        self = .available(value)
        throw error
      }
    case .decoded(let value, let payload):
      self = .decoded(value, payload)
      break
    case .streaming(var state):
      do {
        try await state.finishDecoding(for: property, in: context, using: accessor)
        self = .streaming(state)
      } catch {
        self = .streaming(state)
        throw error
      }
    }
  }

  mutating func beginStreaming(
    for property: StructuredObjectProperty<Root, Definition>
  ) -> sending Definition.ObjectDecoderValue {
    switch consume self {
    case .unavailable:
      /// We miscounted unavailable properties
      fatalError()
    case .seeded(let seed):
      self = .streaming(.notFound)
      return seed.send()
    case .available(let value):
      /// Technically we are mid-stream of the last property to become available which will be set to `decoded` on completion.
      self = .streaming(.notFound)
      return property.definition.objectDecoderValue(from: value.send())
    case .decoded(let value, let payload):
      self = .streaming(.decoded(payload))
      return value.send()
    case .streaming:
      fatalError()
    }
  }

  mutating func validate(
    for property: StructuredObjectProperty<Root, Definition>
  ) async throws -> sending Definition.ValidationPayload {
    switch consume self {
    case .unavailable: fatalError()
    case .seeded: fatalError()
    case .available: fatalError()
    case .decoded: fatalError()
    case .streaming(var state):
      do {
        let payload = try await state.validate(for: property)
        self = .streaming(state)
        return payload
      } catch {
        self = .streaming(state)
        throw error
      }
    }
  }

}

private enum ObjectPropertyStreamedDecodingState<
  Root, Definition: StructuredObjectPropertyDefinition
>: ~Copyable {

  init(_ property: StructuredObjectProperty<Root, Definition>) {
    self = .notFound
  }

  case notFound
  case decoded(Sending<Definition.ValidationPayload>)
  case validating

  var isDecoded: Bool {
    switch self {
    case .notFound: false
    case .decoded: true
    case .validating: fatalError()
    }
  }

  mutating func finishDecoding<Accessor: StructuredAccessor & ~Escapable>(
    for property: StructuredObjectProperty<Root, Definition>,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws
  where Accessor.Value == Root {
    switch consume self {
    case .notFound:
      do {
        let accessor = KeyPathAccessor(base: accessor, keyPath: property.taggedKeyPath)
        let payload = try await property.definition.decodeOmitted(in: context, using: accessor)
        self = .decoded(Sending(payload))
      } catch {
        self = .notFound
        throw error
      }
    case .decoded(let payload):
      self = .decoded(payload)
    case .validating:
      fatalError()
    }
  }

  mutating func validate(
    for property: StructuredObjectProperty<Root, Definition>
  ) async throws -> sending Definition.ValidationPayload {
    switch consume self {
    case .notFound:
      fatalError()
    case .decoded(let p):
      self = .validating
      return p.send()
    case .validating:
      fatalError()
    }
  }

}

// MARK: - Accessors

private struct PreInitializationAccessor<
  Root,
  Definition: StructuredObjectPropertyDefinition
>: StructuredAccessor {

  typealias Value = Definition.PropertyValue

  /// Even though this accesor is technically mutable, streaming doesn't buy us anything if we can't initialize the container yet so we prefer the all-at-once codepath.
  var isMutable: Bool { false }

  func initializeValue(to value: consuming sending Value) async throws {
    stateRef.pointee = .available(Sending(value))
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (borrowing Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await stateRef.pointee.apply(delta) { value, delta in
      try await apply(value, delta)
    }
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Definition.PropertyValue, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    try await stateRef.pointee.apply(delta, with: apply)
  }

  let stateRef: UnsafeMutablePointer<ObjectPropertyBufferedDecodingState<Root, Definition>>

}

private struct InitializingAccessor<
  Base: StructuredAccessor & ~Escapable,
  each PropertyDefinition,
  StreamingDefinition: StructuredObjectPropertyDefinition
>: StructuredAccessor, ~Escapable
where
  Base.Value: StructuredObject,
  Base.Value.StructuredObjectProperties == (
    repeat StructuredObjectProperty<Base.Value, each PropertyDefinition>
  ),
  Base.Value.ObjectDecoderValues == (repeat (each PropertyDefinition).ObjectDecoderValue)
{

  var isMutable: Bool {
    KeyPathAccessor(base: base, keyPath: streamingProperty.taggedKeyPath).isMutable
  }

  func initializeValue(to value: consuming sending StreamingDefinition.PropertyValue) async throws {
    if isInitialized {
      try await KeyPathAccessor(base: base, keyPath: streamingProperty.taggedKeyPath)
        .initializeValue(to: value)
    } else {
      streamingStateRef.pointee = .available(Sending(value))
      try await Base.Value.decode(from: repeat each bufferingStateRefs, using: base)
      isInitialized = true
    }
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply:
      @Sendable (StreamingDefinition.PropertyValue, sending Delta) async throws ->
      sending T
  ) async throws -> sending T {
    if isInitialized {
      try await KeyPathAccessor(base: base, keyPath: streamingProperty.taggedKeyPath)
        .accessValue(applying: delta, apply: apply)
    } else {
      try await streamingStateRef.pointee.apply(delta) { value, delta in
        try await apply(value, delta)
      }
    }
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply:
      @Sendable (inout StreamingDefinition.PropertyValue, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    if isInitialized {
      try await KeyPathAccessor(base: base, keyPath: streamingProperty.taggedKeyPath)
        .mutateValue(applying: delta, apply: apply)
    } else {
      try await streamingStateRef.pointee.apply(delta, with: apply)
    }
  }

  @_lifetime(copy arena, copy base)
  init(
    arena: consuming Arena,
    streamingProperty: StructuredObjectProperty<Base.Value, StreamingDefinition>,
    streamingStateRef: UnsafeMutablePointer<
      ObjectPropertyBufferedDecodingState<Base.Value, StreamingDefinition>
    >,
    bufferingStateRefs: (
      repeat UnsafeMutablePointer<
        ObjectPropertyBufferedDecodingState<Base.Value, each PropertyDefinition>
      >
    ),
    base: Base
  ) {
    self.streamingProperty = streamingProperty
    self.streamingStateRef = streamingStateRef
    self.bufferingStateRefs = (repeat each bufferingStateRefs)
    self.base = base
    self._isInitialized = arena.push(false)
  }
  let streamingProperty: StructuredObjectProperty<Base.Value, StreamingDefinition>
  let streamingStateRef:
    UnsafeMutablePointer<ObjectPropertyBufferedDecodingState<Base.Value, StreamingDefinition>>
  let bufferingStateRefs:
    (
      repeat UnsafeMutablePointer<
        ObjectPropertyBufferedDecodingState<Base.Value, each PropertyDefinition>
      >
    )
  let base: Base

  @ArenaRef private var isInitialized: Bool

}

struct KeyPathAccessor<
  Base: StructuredAccessor & ~Escapable,
  Value
>: StructuredAccessor, ~Escapable {

  var isMutable: Bool {
    switch keyPath {
    case .getOnly, .getOnlyClosure:
      false
    case .writable:
      base.isMutable
    case .referenceWritable:
      true
    }
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    let keyPath = keyPath
    return try await base.accessValue(applying: delta) { root, delta in
      try await apply(keyPath.accessValue(on: root), delta)
    }
  }

  func initializeValue(to value: sending Value) async throws {
    switch keyPath {
    case .getOnly, .getOnlyClosure:
      throw AccessorError.valueIsImmutable
    case .writable(let keyPath):
      try await base.mutateValue(applying: value) { base, value in
        base[keyPath: keyPath] = value
      }
    case .referenceWritable(let keyPath):
      try await base.accessValue(applying: value) { base, value in
        base[keyPath: keyPath] = value
      }
    }
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    switch keyPath {
    case .getOnly, .getOnlyClosure:
      throw AccessorError.valueIsImmutable
    case .writable(let keyPath):
      try await base.mutateValue(applying: delta) { base, delta in
        try await apply(&base[keyPath: keyPath], delta)
      }
    case .referenceWritable(let keyPath):
      try await base.accessValue(applying: delta) { base, delta in
        try await apply(&base[keyPath: keyPath], delta)
      }
    }
  }

  @_lifetime(copy base)
  init(base: consuming Base, keyPath: TaggedKeyPath<Base.Value, Value>) {
    self.base = base
    self.keyPath = keyPath
  }
  var base: Base
  let keyPath: TaggedKeyPath<Base.Value, Value>

}

// MARK: - Implementation Details

private struct Pair<
  First: ~Copyable & Sendable,
  Second: ~Copyable & Sendable
>: ~Copyable & Sendable {
  let first: First
  let second: Second
}

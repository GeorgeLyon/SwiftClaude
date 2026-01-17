import JSONSupport
import SchemaCodingSupport

// MARK: - Object Property

extension SchemaCoding.Support {

  public struct ObjectProperty<Definition: ObjectPropertyDefinition> {

    public init<Schema>(
      name: SchemaCodingKey,
      description: String? = nil,
      schema: Schema
    ) where Definition == DirectObjectPropertyDefinition<Schema> {
      self.name = name
      self.kind = .required
      self.definition = Definition(
        effectiveSchema: schema.prependingDescription(description)
      )
    }

    public init<Schema>(
      name: SchemaCodingKey,
      description: String? = nil,
      schema: OptionalSchema<Schema>
    ) where Definition == OptionalPropertyDefinition<Schema> {
      self.name = name
      self.kind = .optional
      self.definition = Definition(
        effectiveSchema: schema.prependingDescription(description)
      )
    }

    init<WrappedSchema>(
      name: SchemaCodingKey,
      description: String? = nil,
      schema: ConstantSchema<OptionalSchema<WrappedSchema>>
    )
    where
      Definition == DirectObjectPropertyDefinition<
        ConstantSchema<OptionalSchema<WrappedSchema>>
      >
    {
      self.name = name
      self.kind = schema.constantValue == nil ? .omitted(()) : .required
      self.definition = Definition(
        effectiveSchema: schema.prependingDescription(description)
      )
    }

    typealias Value = Definition.Value

    var isRequired: Bool {
      if case .required = kind {
        true
      } else {
        false
      }
    }

    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder) {
      if case .omitted = kind {
        return
      } else {
        definition.encode(value, for: name, to: &encoder)
      }
    }

    func propertyDecoder(for decoder: borrowing Decoder) -> PropertyDecoder {
      PropertyDecoder(
        property: self,
        decoder: decoder
      )
    }

    typealias MetaProperty = ObjectProperty<Definition.MetaPropertyDefinition>
    var metaProperty: MetaProperty {
      let kind: MetaProperty.Kind =
        switch kind {
        case .required, .optional:
          .required
        case .omitted:
          .omitted(definition.propertySchema)
        }
      return MetaProperty(
        name: name,
        kind: kind,
        definition: definition.metaPropertyDefinition
      )
    }

    struct PropertyDecoder: ObjectPropertyDecoder {

      func decode(
        from decoder: inout Decoder
      ) throws -> DecodingResult<Void> {
        if case .omitted = property.kind {
          throw Error.propertyNotOmitted(property.name.stringValue)
        }

        return try decoder.arena.withValue(reference) { decodingState in
          var state: Definition.PropertySchema.ValueDecodingState
          switch decodingState {
          case .decoded:
            throw Error.propertyAlreadyDecoded
          case .encounteredError(let error):
            assertionFailure()
            throw error
          case .notFound:
            state = property.definition.beginDecodingValue(from: decoder)
          case .decoding(let s):
            state = s
          }

          do {
            switch try property.definition.decodeValue(from: &decoder, state: &state).kind {
            case .decoded(let value):
              decodingState = .decoded(value)
              return .decoded
            case .incomplete:
              decodingState = .decoding(state)
              return .incomplete
            }
          } catch {
            decodingState = .encounteredError(error)
            throw error
          }
        }
      }

      func finishDecoding(
        from decoder: borrowing Decoder
      ) throws -> Value {
        try decoder.arena.withValue(reference) { decodingState in
          switch decodingState {
          case .encounteredError(let error):
            throw error
          case .decoding:
            throw Error.partiallyDecoded
          case .notFound:
            if case .omitted(let propertyValue) = property.kind,
              let value = Definition.value(from: propertyValue)
            {
              return value
            } else if let value: Value = Definition.value(from: nil) {
              return value
            } else {
              throw Error.propertyNotFound(property.name.stringValue)
            }
          case .decoded(let value):
            return value
          }
        }
      }

      fileprivate init(
        property: ObjectProperty,
        decoder: borrowing Decoder
      ) {
        self.property = property
        self.reference = decoder.arena.push(.notFound)
      }

      private enum DecodingState {
        case notFound
        case decoding(Definition.PropertySchema.ValueDecodingState)
        case decoded(Definition.EffectiveSchema.Value)
        case encounteredError(Swift.Error)
      }

      private let property: ObjectProperty
      private let reference: Arena.Reference<DecodingState>

    }

    private enum Kind {
      case required
      case optional
      case omitted(Definition.PropertySchema.Value)
    }

    private init(
      name: SchemaCodingKey,
      kind: Kind,
      definition: Definition
    ) {
      self.name = name
      self.kind = kind
      self.definition = definition
    }
    private let name: SchemaCodingKey
    private let kind: Kind
    private let definition: Definition

  }

  public protocol ObjectPropertyDefinition {

    associatedtype EffectiveSchema: Schema
    // var effectiveSchema: EffectiveSchema { get }
    // init(effectiveSchema: EffectiveSchema)

    associatedtype PropertySchema: Schema
    var propertySchema: PropertySchema { get }

    func encode(
      _ value: Value,
      for propertyName: SchemaCodingKey,
      to encoder: inout ObjectPropertiesEncoder
    )

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> PropertySchema.ValueDecodingState

    func decodeValue(
      from decoder: inout Decoder,
      state: inout PropertySchema.ValueDecodingState
    ) throws -> DecodingResult<Value>

    static func propertyValue(from value: Value) -> PropertySchema.Value?
    static func value(from propertyValue: PropertySchema.Value?) -> Value?

    associatedtype MetaPropertyDefinition: ObjectPropertyDefinition
    where MetaPropertyDefinition.PropertySchema == PropertySchema.MetaSchema
    var metaPropertyDefinition: MetaPropertyDefinition { get }

  }

}

extension SchemaCoding.Support.ObjectPropertyDefinition {
  public typealias Value = EffectiveSchema.Value
}

// MARK: - Direct Properties

extension SchemaCoding.Support {

  public struct DirectObjectPropertyDefinition<
    Schema: SchemaCoding.Schema
  >: ObjectPropertyDefinition {
    public typealias EffectiveSchema = Schema
    public typealias PropertySchema = Schema

    public func encode(
      _ value: Value,
      for propertyName: SchemaCodingKey,
      to encoder: inout ObjectPropertiesEncoder
    ) {
      encoder.encoder.encodeProperty(name: propertyName) { stream in
        stream.encode(value, using: propertySchema)
      }
    }

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> PropertySchema.ValueDecodingState {
      propertySchema.beginDecodingValue(from: decoder)
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout PropertySchema.ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try propertySchema.decodeValue(from: &decoder, state: &state)
    }

    public static func propertyValue(from value: Value) -> Schema.Value? {
      value
    }
    public static func value(from propertyValue: Schema.Value?) -> Value? {
      propertyValue
    }

    public typealias MetaPropertyDefinition = DirectObjectPropertyDefinition<Schema.MetaSchema>
    public var metaPropertyDefinition: MetaPropertyDefinition {
      MetaPropertyDefinition(effectiveSchema: propertySchema.metaSchema)
    }

    public init(
      effectiveSchema: EffectiveSchema
    ) {
      self.effectiveSchema = effectiveSchema
    }
    public var propertySchema: PropertySchema {
      effectiveSchema
    }
    public let effectiveSchema: EffectiveSchema
  }

}

// MARK: - Optional Properties

extension SchemaCoding.Support {

  public struct OptionalPropertyDefinition<
    PropertySchema: SchemaCoding.Schema
  >: ObjectPropertyDefinition {
    public typealias EffectiveSchema = OptionalSchema<PropertySchema>

    public func encode(
      _ value: Value,
      for propertyName: SchemaCodingKey,
      to encoder: inout ObjectPropertiesEncoder
    ) {
      guard let value else {
        return
      }
      encoder.encoder.encodeProperty(name: propertyName) { stream in
        stream.encode(value, using: propertySchema)
      }
    }

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> PropertySchema.ValueDecodingState {
      propertySchema.beginDecodingValue(from: decoder)
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout PropertySchema.ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try propertySchema
        .decodeValue(from: &decoder, state: &state)
        .map { $0 }
    }

    public static func propertyValue(from value: Value) -> PropertySchema.Value? {
      value
    }
    public static func value(from propertyValue: PropertySchema.Value?) -> Value? {
      propertyValue
    }

    public var valueWhenOmitted: Value? {
      .some(.none)
    }

    public typealias MetaPropertyDefinition = DirectObjectPropertyDefinition<
      PropertySchema.MetaSchema
    >
    public var metaPropertyDefinition: MetaPropertyDefinition {
      MetaPropertyDefinition(effectiveSchema: propertySchema.metaSchema)
    }

    public init(
      effectiveSchema: EffectiveSchema
    ) {
      self.effectiveSchema = effectiveSchema
    }

    public var propertySchema: PropertySchema {
      effectiveSchema.wrappedSchema.prependingDescription(effectiveSchema.description)
    }

    public let effectiveSchema: EffectiveSchema

  }

}

// MARK: - Decoder

extension SchemaCoding.Support {

  protocol ObjectPropertyDecoder {

    func decode(from decoder: inout Decoder) throws -> DecodingResult<Void>

    associatedtype Value
    func finishDecoding(from decoder: borrowing Decoder) throws -> Value

  }

}

/*
extension SchemaCoding.Support {

  public protocol ObjectProperty<Value> {
    var name: SchemaCodingKey { get }

    associatedtype Value
    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder)
    associatedtype Decoder: ObjectPropertyDecoder<Value>
    func beginDecoding(from decoder: borrowing SchemaCoding.Support.Decoder) -> Decoder

    associatedtype PropertySchema: SchemaCoding.Schema
    var propertySchema: PropertySchema { get }

    associatedtype EffectiveSchema: SchemaCoding.Schema where EffectiveSchema.Value == Value

    associatedtype MetaProperty: ObjectProperty where MetaProperty.Value == Self
    var metaProperty: MetaProperty { get }

    var metadata: ObjectPropertyMetadata { get }
  }

  public protocol ObjectPropertyDecoder<Value> {
    var propertyName: String { get }

    func decode(from decoder: inout Decoder) throws -> DecodingResult<Void>

    associatedtype Value
    func finishDecoding(from decoder: borrowing Decoder) throws -> Value
  }

  public struct ObjectPropertyMetadata {
    var kind: ObjectPropertyKind
  }

  enum ObjectPropertyKind {
    case required, optional, omitted
  }

}

// MARK: - Direct Properties

extension SchemaCoding.Support {

  /// An object property whose value is the same as the value of its schema
  struct DirectObjectProperty<Schema: SchemaCoding.Schema>:
    InternalObjectProperty
  {

    typealias PropertySchema = Schema
    typealias EffectiveSchema = Schema

    typealias Decoder = ConcreteObjectPropertyDecoder<Self>

    typealias Value = Schema.Value

    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder) {
      encoder.encoder.encodeProperty(name: name.stringValue) { stream in
        stream.encode(value, using: propertySchema)
      }
    }

    func beginDecoding(
      from decoder: borrowing SchemaCoding.Support.Decoder
    ) -> ConcreteObjectPropertyDecoder<Self> {
      ConcreteObjectPropertyDecoder(
        property: self,
        reference: decoder.arena.push(.notFound)
      )
    }

    struct MetaProperty: WrapperObjectProperty {
      let wrappedProperty: DirectObjectProperty<Schema.MetaSchema>
      static func wrap(_ wrappedValue: Schema.MetaSchema.Value) -> Value {
      code
      }
    }
    var metaProperty: MetaProperty {
      MetaProperty(
        wrappedProperty: DirectObjectProperty<_>(
          name: name,
          schema: propertySchema.metaSchema,
          kind: metadata.kind == .omitted ? .omitted(constantValue: propertySchema) : .required
        ),
        wrap: { propertySchema in
          return Self(
            name: name,
            schema: propertySchema,
            kind: kind
          )
        },
        unwrap: { schema in
          schema.propertySchema
        }
      )
    }

    var metadata: ObjectPropertyMetadata {
      switch kind {
      case .required:
        ObjectPropertyMetadata(kind: .required)
      case .omitted:
        ObjectPropertyMetadata(kind: .omitted)
      }
    }

    func notFoundValue() throws -> Value {
      switch kind {
      case .omitted(let constantValue):
        return constantValue
      case .required:
        throw Error.missingProperty(name.stringValue)
      }
    }

    func value(from schemaValue: Schema.Value) throws -> Value {
      guard metadata.kind != .omitted else {
        throw Error.propertyNotOmitted(name.stringValue)
      }
      return schemaValue
    }

    init<WrappedSchema>(
      name: SchemaCodingKey,
      description: String? = nil,
      constantOptionalSchema schema: ConstantSchema<OptionalSchema<WrappedSchema>>
    ) where Schema == ConstantSchema<OmissibleOptionalSchema<WrappedSchema>> {
      self.init(
        name: name,
        description: description,
        schema: ConstantSchema(
          wrappedSchema: OmissibleOptionalSchema(
            wrappedSchema: schema.wrappedSchema.wrappedSchema
              .prependingDescription(schema.wrappedSchema.description)
          ),
          constantValue: schema.constantValue
        ),
        kind: schema.constantValue == nil ? .omitted(constantValue: ()) : .required,
      )
    }

    init(
      name: SchemaCodingKey,
      description: String? = nil,
      schema: Schema,
      kind: Kind = .required,
    ) {
      self.name = name
      self.propertySchema = schema.prependingDescription(description)
      self.kind = kind
    }

    let name: SchemaCodingKey
    let propertySchema: Schema

    enum Kind {
      case required
      case omitted(constantValue: Schema.Value)
    }
    private let kind: Kind

  }

}

// MARK: - Optional Properties

extension SchemaCoding.Support {

  struct OptionalObjectProperty<Schema: SchemaCoding.Schema>:
    InternalObjectProperty
  {

    typealias PropertySchema = Schema
    typealias EffectiveSchema = OptionalSchema<Schema>

    typealias Value = Schema.Value?

    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder) {
      guard let value else {
        return
      }
      encoder.encoder.encodeProperty(name: name.stringValue) { stream in
        stream.encode(value, using: propertySchema)
      }
    }

    typealias Decoder = ConcreteObjectPropertyDecoder<Self>
    func beginDecoding(
      from decoder: borrowing SchemaCoding.Support.Decoder
    ) -> Decoder {
      Decoder(
        property: self,
        reference: decoder.arena.push(.notFound)
      )
    }

    struct MetaSchema
    typealias MetaProperty = DirectObjectProperty<WrapperSchema<Self, Schema.MetaSchema>>
    var metaProperty: MetaProperty {
      MetaProperty(
        name: name,
        schema: propertySchema.metaSchema.wrap { propertySchema in
          Self(name: name, propertySchema: propertySchema)
        } unwrap: { property in
          property.propertySchema
        }
      )
    }

    func notFoundValue() throws -> Value {
      nil
    }

    func value(from schemaValue: Schema.Value) -> Schema.Value? {
      schemaValue
    }

    init(
      name: SchemaCodingKey,
      description: String? = nil,
      schema: OptionalSchema<Schema>
    ) {
      self.name = name
      self.propertySchema = schema
        .wrappedSchema
        .prependingDescription(schema.description)
        .prependingDescription(description)
    }

    private init(
      name: SchemaCodingKey,
      propertySchema: Schema
    ) {
      self.name = name
      self.propertySchema = propertySchema
    }
    let name: SchemaCodingKey
    let propertySchema: Schema
    var metadata: ObjectPropertyMetadata {
      ObjectPropertyMetadata(kind: .optional)
    }

  }

}

// MARK: - Wrapping Properties

extension SchemaCoding.Support {

  protocol WrapperObjectProperty: ObjectProperty {
    associatedtype WrappedProperty: ObjectProperty
    init(wrappedProperty: WrappedProperty)
    var wrappedProperty: WrappedProperty { get }
    static func wrap(_ wrappedValue: WrappedProperty.Value) -> Value
    static func unwrap(_ value: Value) -> WrappedProperty.Value
  }

  struct WrapperObjectPropertyDecoder<Property: WrapperObjectProperty>: ObjectPropertyDecoder {
    typealias Value = Property.Value
    func decode(
      from decoder: inout SchemaCoding.Support.Decoder
    ) throws -> DecodingResult<Void> {
      try wrappedDecoder.decode(from: &decoder)
    }
    func finishDecoding(from decoder: borrowing SchemaCoding.Support.Decoder) throws -> Value {
      Property.wrap(try wrappedDecoder.finishDecoding(from: decoder))
    }
    var propertyName: String {
      wrappedDecoder.propertyName
    }
    let wrappedDecoder: Property.WrappedProperty.Decoder
  }

  struct WrapperObjectPropertyEffectiveSchema<Property: WrapperObjectProperty>: WrapperSchema {
    typealias Value = Property.Value
    var wrappedSchema: Property.WrappedProperty.EffectiveSchema
    static func wrap(_ value: WrappedSchema.Value) -> Value {
      Property.wrap(value)
    }
    static func unwrap(_ value: Value) -> WrappedSchema.Value {
      Property.unwrap(value)
    }
  }

  struct WrapperMetaObjectProperty<Value: WrapperObjectProperty>: WrapperObjectProperty {
    typealias EffectiveSchema = _EffectiveSchema
    var wrappedProperty: Value.WrappedProperty.MetaProperty
    static func wrap(_ wrappedValue: WrappedProperty.Value) -> Value {
      Value(wrappedProperty: wrappedValue)
    }
    static func unwrap(_ value: Value) -> WrappedProperty.Value {
      value.wrappedProperty
    }
  }

}

extension SchemaCoding.Support.WrapperObjectProperty {

  typealias _EffectiveSchema = SchemaCoding.Support.WrapperObjectPropertyEffectiveSchema<Self>

  func encode(_ value: Value, to encoder: inout SchemaCoding.Support.ObjectPropertiesEncoder) {
    wrappedProperty.encode(Self.unwrap(value), to: &encoder)
  }

  typealias _Decoder = SchemaCoding.Support.WrapperObjectPropertyDecoder<Self>

  func beginDecoding(
    from decoder: borrowing SchemaCoding.Support.Decoder
    ) -> _Decoder {
    _Decoder(
      wrappedDecoder: wrappedProperty.beginDecoding(from: decoder)
    )
  }

  typealias _MetaProperty = SchemaCoding.Support.WrapperMetaObjectProperty<Self>
  var metaProperty: _MetaProperty {
    _MetaProperty(wrappedProperty: wrappedProperty.metaProperty)
  }

  var name: SchemaCoding.Support.SchemaCodingKey {
    wrappedProperty.name
  }

  var propertySchema: WrappedProperty.PropertySchema {
    wrappedProperty.propertySchema
  }

  var metadata: SchemaCoding.Support.ObjectPropertyMetadata {
    wrappedProperty.metadata
  }

}

extension SchemaCoding.Support {

  struct OmissibleOptionalSchema<WrappedSchema: Schema>: Schema {

    typealias Value = WrappedSchema.Value?

    func encode(_ value: Value, to encoder: inout Encoder) {
      guard let value else {
        /// `nil` values must always be omitted
        assertionFailure()
        return
      }
      wrappedSchema.encode(value, to: &encoder)
    }

    typealias ValueDecodingState = WrappedSchema.ValueDecodingState

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      wrappedSchema.beginDecodingValue(from: decoder)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try wrappedSchema.decodeValue(from: &decoder, state: &state).map { $0 }
    }

    typealias MetaSchema = WrapperSchema<Self, WrappedSchema.MetaSchema>
    var metaSchema: MetaSchema {
      wrappedSchema.metaSchema.wrap { wrappedSchema in
        Self(wrappedSchema: wrappedSchema)
      } unwrap: { schema in
        schema.wrappedSchema
      }
    }

    var metadata: SchemaMetadata {
      get { wrappedSchema.metadata }
      set { wrappedSchema.metadata = newValue }
    }

    init(
      wrappedSchema: WrappedSchema
    ) {
      self.wrappedSchema = wrappedSchema
    }
    var wrappedSchema: WrappedSchema

  }

}

// MARK: - Object Properties Builder

extension SchemaCoding.Support {

  @resultBuilder
  enum ObjectPropertiesBuilder {

    static func buildBlock() -> ObjectProperties<> {
      ObjectProperties(properties: ())
    }

    static func buildPartialBlock<First: ObjectProperty>(
      first: First
    ) -> ObjectProperties<First> {
      ObjectProperties(properties: first)
    }

    static func buildPartialBlock<each Property, Next: ObjectProperty>(
      accumulated: ObjectProperties<repeat each Property>,
      next: Next
    ) -> ObjectProperties<repeat each Property, Next> {
      ObjectProperties(properties: (repeat each accumulated.properties, next))
    }

  }

  struct ObjectProperties<each Property: ObjectProperty> {
    let properties: (repeat each Property)
  }

}

// MARK: - Decoding

extension SchemaCoding.Support {

  protocol InternalObjectProperty: ObjectProperty {
    func notFoundValue() throws -> Value
    func value(from schemaValue: PropertySchema.Value) throws -> Value
  }

  struct ConcreteObjectPropertyDecoder<
    Property: InternalObjectProperty
  >: ObjectPropertyDecoder {

    func decode(
      from decoder: inout SchemaCoding.Support.Decoder
    ) throws -> SchemaCoding.Support.DecodingResult<Void> {
      try decoder.arena.withValue(reference) { decodingState in
        var state: Property.PropertySchema.ValueDecodingState
        switch decodingState {
        case .decoded:
          throw Error.propertyAlreadyDecoded
        case .invalid:
          throw Error.invalidState
        case .notFound:
          state = property.propertySchema.beginDecodingValue(from: decoder)
        case .decoding(let s):
          state = s
        }

        decodingState = .invalid
        switch try property.propertySchema.decodeValue(from: &decoder, state: &state).kind {
        case .decoded(let value):
          decodingState = .decoded(value)
          return .decoded
        case .incomplete:
          decodingState = .decoding(state)
          return .incomplete
        }
      }
    }

    func finishDecoding(
      from decoder: borrowing SchemaCoding.Support.Decoder
    ) throws -> Property.Value {
      try decoder.arena.withValue(reference) { decodingState in
        switch decodingState {
        case .invalid:
          throw Error.invalidState
        case .decoding:
          throw Error.partiallyDecoded
        case .notFound:
          return try property.notFoundValue()
        case .decoded(let value):
          return try property.value(from: value)
        }
      }
    }
    private let reference: Arena.Reference<DecodingState>

    var propertyName: String {
      property.name.stringValue
    }

    enum DecodingState {
      case notFound
      case decoding(Property.PropertySchema.ValueDecodingState)
      case decoded(Property.PropertySchema.Value)
      case invalid
    }

    init(
      property: Property,
      reference: Arena.Reference<DecodingState>
    ) {
      self.property = property
      self.reference = reference
    }

    private let property: Property
    private let reference: Arena.Reference<DecodingState>

  }

}

// MARK: - Implementation Details

extension SchemaCoding.Support.ConcreteObjectPropertyDecoder.DecodingState: BitwiseCopyable
where
  Property.PropertySchema.ValueDecodingState: BitwiseCopyable,
  Property.PropertySchema.Value: BitwiseCopyable
{

}
*/

// MARK: - Errors

private enum Error: Swift.Error {
  case propertyAlreadyDecoded
  case partiallyDecoded
  case propertyNotFound(String)
  case propertyNotOmitted(String)
}

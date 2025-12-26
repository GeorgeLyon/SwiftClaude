import JSONSupport
import SchemaCodingSupport

// MARK: - Object Property

extension SchemaCoding.Support {

  public protocol ObjectProperty<Value> {
    var name: SchemaCodingKey { get }

    associatedtype Value
    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder)
    associatedtype Decoder: ObjectPropertyDecoder<Value>
    func beginDecoding(from decoder: borrowing SchemaCoding.Support.Decoder) -> Decoder

    associatedtype PropertySchema: SchemaCoding.Schema
    var propertySchema: PropertySchema { get }

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

// MARK: - Required Properties

extension SchemaCoding.Support {

  /// An object property whose value is the same as the value of its schema
  struct DirectObjectProperty<Schema: SchemaCoding.Schema>:
    InternalObjectProperty
  {

    typealias PropertySchema = Schema

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

    typealias MetaProperty = WrapperObjectProperty<Self, DirectObjectProperty<Schema.MetaSchema>>
    var metaProperty: MetaProperty {
      MetaProperty(
        wrappedProperty: DirectObjectProperty<_>(
          name: name,
          propertySchema: propertySchema.metaSchema,
          kind: metadata.kind == .omitted ? .omitted : .required
        ),
        wrap: { propertySchema in
          return Self(
            name: name,
            propertySchema: propertySchema,
            kind: metadata.kind
          )
        },
        unwrap: { schema in
          schema.propertySchema
        }
      )
    }

    func notFoundValue() throws -> Value {
      throw Error.missingProperty(name.stringValue)
    }

    func value(from schemaValue: Schema.Value) -> Value {
      schemaValue
    }

    init<WrappedSchema>(
      name: SchemaCodingKey,
      description: String? = nil,
      schema: ConstantSchema<OptionalSchema<WrappedSchema>>
    ) where Schema == ConstantSchema<OmissibleOptionalSchema<WrappedSchema>> {
      self.init(
        name: name,
        propertySchema: ConstantSchema(
          wrappedSchema: OmissibleOptionalSchema(
            wrappedSchema: schema.wrappedSchema.wrappedSchema
              .prependingDescription(schema.wrappedSchema.description)
          ),
          constantValue: schema.constantValue
        ),
        kind: schema.constantValue == nil ? .omitted : .required
      )
    }

    init(
      name: SchemaCodingKey,
      description: String? = nil,
      schema: Schema
    ) {
      self.init(
        name: name,
        propertySchema: schema,
        kind: .required
      )
    }

    private init(
      name: SchemaCodingKey,
      description: String? = nil,
      propertySchema: Schema,
      kind: ObjectPropertyKind
    ) {
      self.name = name
      self.propertySchema = propertySchema.prependingDescription(description)
      self.metadata = ObjectPropertyMetadata(kind: kind)
    }

    let name: SchemaCodingKey
    let propertySchema: Schema
    let metadata: ObjectPropertyMetadata

  }

}

// MARK: - Optional Properties

extension SchemaCoding.Support {

  struct OptionalObjectProperty<Schema: SchemaCoding.Schema>:
    InternalObjectProperty
  {

    typealias PropertySchema = Schema

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

  struct WrapperObjectProperty<NewValue, WrappedProperty: ObjectProperty>: ObjectProperty {

    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder) {
      wrappedProperty.encode(unwrap(value), to: &encoder)
    }

    struct Decoder: ObjectPropertyDecoder {
      typealias Value = NewValue
      func decode(
        from decoder: inout SchemaCoding.Support.Decoder
      ) throws -> DecodingResult<Void> {
        try wrappedDecoder.decode(from: &decoder)
      }
      func finishDecoding(from decoder: borrowing SchemaCoding.Support.Decoder) throws -> NewValue {
        wrap(try wrappedDecoder.finishDecoding(from: decoder))
      }
      var propertyName: String {
        wrappedDecoder.propertyName
      }
      let wrappedDecoder: WrappedProperty.Decoder
      let wrap: (WrappedProperty.Value) -> NewValue
    }
    func beginDecoding(from decoder: borrowing SchemaCoding.Support.Decoder)
      -> Decoder
    {
      Decoder(
        wrappedDecoder: wrappedProperty.beginDecoding(from: decoder),
        wrap: wrap
      )
    }

    typealias MetaProperty = WrapperObjectProperty<Self, WrappedProperty.MetaProperty>
    var metaProperty: MetaProperty {
      MetaProperty(
        wrappedProperty: wrappedProperty.metaProperty,
        wrap: { wrappedProperty in
          Self(wrappedProperty: wrappedProperty, wrap: wrap, unwrap: unwrap)
        },
        unwrap: { property in
          property.wrappedProperty
        }
      )
    }

    var name: SchemaCodingKey {
      wrappedProperty.name
    }

    var propertySchema: WrappedProperty.PropertySchema {
      wrappedProperty.propertySchema
    }

    var metadata: ObjectPropertyMetadata {
      wrappedProperty.metadata
    }

    fileprivate let wrappedProperty: WrappedProperty
    fileprivate let wrap: (WrappedProperty.Value) -> NewValue
    fileprivate let unwrap: (NewValue) -> WrappedProperty.Value

  }

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

private enum Error: Swift.Error {
  case invalidState
  case propertyAlreadyDecoded
  case partiallyDecoded
  case missingProperty(String)
  case propertyNotOmitted(String)
}

extension SchemaCoding.Support.ConcreteObjectPropertyDecoder.DecodingState: BitwiseCopyable
where
  Property.PropertySchema.ValueDecodingState: BitwiseCopyable,
  Property.PropertySchema.Value: BitwiseCopyable
{

}

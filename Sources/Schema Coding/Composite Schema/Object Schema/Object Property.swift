import JSONSupport
import SchemaCodingSupport

// MARK: - Object Property

extension SchemaCoding.Support {

  public protocol ObjectProperty<Value>: Sendable {
    var name: ObjectPropertyName { get }

    var isRequired: Bool { get }

    associatedtype Value
    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder)
    associatedtype Decoder: ObjectPropertyDecoder<Value>
    func beginDecoding(from decoder: borrowing SchemaCoding.Support.Decoder) -> Decoder

    associatedtype Schema: SchemaCoding.Schema
    var schema: Schema { get }

    associatedtype MetaProperty: ObjectProperty where MetaProperty.Value == Self
    var metaProperty: MetaProperty { get }
  }

  public protocol ObjectPropertyDecoder<Value> {
    var propertyName: String { get }

    func decode(from decoder: inout Decoder) throws -> DecodingResult<Void>

    associatedtype Value
    func finishDecoding(from decoder: borrowing Decoder) throws -> Value
  }

}

// MARK: - Required Properties

extension SchemaCoding.Support {

  struct RequiredObjectProperty<Schema: SchemaCoding.Schema>:
    InternalObjectProperty
  {

    typealias Decoder = ConcreteObjectPropertyDecoder<Self>

    typealias Value = Schema.Value

    var isRequired: Bool {
      true
    }

    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder) {
      encoder.encoder.encodeProperty(name: name.stringValue) { stream in
        stream.encode(value, using: schema)
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

    typealias MetaProperty = RequiredObjectProperty<WrapperSchema<Self, Schema.MetaSchema>>
    var metaProperty: MetaProperty {
      RequiredObjectProperty<_>(
        name: name,
        schema: schema.metaSchema.wrap { wrapped in
          Self(name: name, schema: wrapped)
        } unwrap: { property in
          property.schema
        }
      )
    }

    func notFoundValue() throws -> Value {
      throw Error.missingProperty(name.stringValue)
    }

    func value(from schemaValue: Schema.Value) -> Value {
      schemaValue
    }

    let name: ObjectPropertyName
    let schema: Schema

  }

}

// MARK: - Optional Properties

extension SchemaCoding.Support {

  struct OptionalObjectProperty<Schema: SchemaCoding.Schema>:
    InternalObjectProperty
  {

    typealias Value = Schema.Value?

    var isRequired: Bool {
      false
    }

    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder) {
      guard let value else {
        return
      }
      encoder.encoder.encodeProperty(name: name.stringValue) { stream in
        stream.encode(value, using: schema)
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

    typealias MetaProperty = RequiredObjectProperty<WrapperSchema<Self, Schema.MetaSchema>>
    var metaProperty: MetaProperty {
      MetaProperty(
        name: name,
        schema: schema.metaSchema.wrap { wrapped in
          Self(name: name, schema: wrapped)
        } unwrap: { property in
          property.schema
        }
      )
    }

    func notFoundValue() throws -> Value {
      nil
    }

    func value(from schemaValue: Schema.Value) -> Schema.Value? {
      schemaValue
    }

    let name: ObjectPropertyName
    let schema: Schema

  }

}

// MARK: - Constant Optional Properties

extension SchemaCoding.Support {

  struct ConstantOptionalObjectProperty<
    Schema: SchemaCoding.Schema
  >: InternalObjectProperty where Schema.Value == Void {

    typealias Value = Void

    var isRequired: Bool {
      !isNone
    }

    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder) {
      guard !isNone else { return }
      encoder.encoder.encodeProperty(name: name.stringValue) { stream in
        stream.encode(value, using: schema)
      }
    }

    typealias Decoder = ConcreteObjectPropertyDecoder<Self>
    func beginDecoding(
      from decoder: borrowing SchemaCoding.Support.Decoder
    ) -> ConcreteObjectPropertyDecoder<Self> {
      ConcreteObjectPropertyDecoder(
        property: self,
        reference: decoder.arena.push(.notFound)
      )
    }

    typealias MetaProperty = WrapperProperty<
      Self,
      ConstantOptionalObjectProperty<WrapperSchema<Void, Schema.MetaSchema>>
    >
    var metaProperty: MetaProperty {
      MetaProperty(
        wrappedProperty: ConstantOptionalObjectProperty<_>(
          name: name,
          isNone: isNone,
          schema: schema.metaSchema.wrap { wrapped in
            ()
          } unwrap: { _ in
            schema
          }
        ),
        wrap: { _ in
          self
        },
        unwrap: { _ in
          ()
        }
      )
    }

    func notFoundValue() throws {
      guard isNone else {
        throw Error.missingProperty(name.stringValue)
      }
    }

    func value(from schemaValue: Schema.Value) throws {
      guard !isNone else {
        throw Error.propertyNotOmitted(name.stringValue)
      }
    }

    init<WrappedSchema>(
      name: ObjectPropertyName,
      schema: WrappedSchema,
      constantValue: WrappedSchema.Value?
    ) where Schema == ConstantSchema<OmissibleOptionalSchema<WrappedSchema>> {
      self.name = name
      self.isNone = constantValue == nil
      self.schema = ConstantSchema(
        description: nil,
        wrappedSchema: OmissibleOptionalSchema(wrappedSchema: schema),
        constantValue: constantValue
      )
    }

    private init(
      name: ObjectPropertyName,
      isNone: Bool,
      schema: Schema
    ) {
      self.name = name
      self.isNone = isNone
      self.schema = schema
    }
    let name: ObjectPropertyName
    let isNone: Bool
    let schema: Schema

  }

  struct WrapperProperty<NewValue, WrappedProperty: ObjectProperty>: ObjectProperty {

    var isRequired: Bool {
      wrappedProperty.isRequired
    }

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
      let wrap: @Sendable (WrappedProperty.Value) -> NewValue
    }
    func beginDecoding(from decoder: borrowing SchemaCoding.Support.Decoder)
      -> Decoder
    {
      Decoder(
        wrappedDecoder: wrappedProperty.beginDecoding(from: decoder),
        wrap: wrap
      )
    }

    typealias MetaProperty = WrapperProperty<Self, WrappedProperty.MetaProperty>
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

    var name: ObjectPropertyName {
      wrappedProperty.name
    }

    var schema: WrappedProperty.Schema {
      wrappedProperty.schema
    }

    fileprivate let wrappedProperty: WrappedProperty
    fileprivate let wrap: @Sendable (WrappedProperty.Value) -> NewValue
    fileprivate let unwrap: @Sendable (NewValue) -> WrappedProperty.Value

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

// MARK: - Object Property Name

extension SchemaCoding.Support {

  public struct ObjectPropertyName: ExpressibleByStringLiteral, Sendable {
    public init(stringLiteral value: StaticString) {
      stringValue = "\(value)"
    }
    let stringValue: String

    static let description: Self = "description"
    static let properties: Self = "properties"
    static let required: Self = "required"
    static let items: Self = "items"
    static let type: Self = "type"
    static let value: Self = "value"
    static let const: Self = "const"
  }

}

// MARK: - Object Properties Builder

extension SchemaCoding.Support {

  @resultBuilder
  public enum ObjectPropertiesBuilder {

    public static func buildPartialBlock<First: ObjectProperty>(
      first: First
    ) -> ObjectProperties<First> {
      ObjectProperties(properties: first)
    }

    public static func buildPartialBlock<each Property, Next: ObjectProperty>(
      accumulated: ObjectProperties<repeat each Property>,
      next: Next
    ) -> ObjectProperties<repeat each Property, Next> {
      ObjectProperties(properties: (repeat each accumulated.properties, next))
    }

  }

  public struct ObjectProperties<each Property: ObjectProperty>: Sendable {
    let properties: (repeat each Property)
  }

}

// MARK: - Decoding

extension SchemaCoding.Support {

  protocol InternalObjectProperty: ObjectProperty {
    func notFoundValue() throws -> Value
    func value(from schemaValue: Schema.Value) throws -> Value
  }

  struct ConcreteObjectPropertyDecoder<
    Property: InternalObjectProperty
  >: ObjectPropertyDecoder {

    func decode(
      from decoder: inout SchemaCoding.Support.Decoder
    ) throws -> SchemaCoding.Support.DecodingResult<Void> {
      try decoder.arena.withValue(reference) { decodingState in
        var state: Property.Schema.ValueDecodingState
        switch decodingState {
        case .decoded:
          throw Error.propertyAlreadyDecoded
        case .invalid:
          throw Error.invalidState
        case .notFound:
          state = property.schema.beginDecodingValue(from: decoder)
        case .decoding(let s):
          state = s
        }

        decodingState = .invalid
        switch try property.schema.decodeValue(from: &decoder, state: &state).kind {
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
      case decoding(Property.Schema.ValueDecodingState)
      case decoded(Property.Schema.Value)
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
where Property.Schema.ValueDecodingState: BitwiseCopyable, Property.Schema.Value: BitwiseCopyable {

}

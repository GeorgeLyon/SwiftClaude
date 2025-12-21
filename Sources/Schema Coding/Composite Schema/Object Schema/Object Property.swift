import JSONSupport
import SchemaCodingSupport

// MARK: - Object Property

extension SchemaCoding.Support {

  public static func objectProperty<Schema: SchemaCoding.Schema>(
    name: ObjectPropertyName,
    schema: Schema
  ) -> some ObjectProperty<Schema.Value> {
    RequiredObjectProperty<Schema>(
      name: name,
      schema: schema
    )
  }

  public static func objectProperty<WrappedSchema>(
    name: ObjectPropertyName,
    schema: OptionalSchema<WrappedSchema>
  ) -> some ObjectProperty<WrappedSchema.Value?> {
    OptionalObjectProperty<WrappedSchema>(
      name: name,
      schema: schema.wrappedSchema
    )
  }

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
        schema: schema.metaSchema(in: SchemaContext()).wrap { wrapped in
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
      /// Use the wrapped schema in the meta-property since `.none` is represented by omission
      MetaProperty(
        name: name,
        schema: schema.metaSchema(
          in: SchemaContext()
        ).wrap { wrapped in
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
    func value(from schemaValue: Schema.Value) -> Value
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
          return property.value(from: value)
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
}

extension SchemaCoding.Support.ConcreteObjectPropertyDecoder.DecodingState: BitwiseCopyable
where Property.Schema.ValueDecodingState: BitwiseCopyable, Property.Schema.Value: BitwiseCopyable {

}

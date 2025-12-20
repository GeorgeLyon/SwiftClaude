import JSONSupport
import SchemaCodingSupport

// MARK: - Object Property

extension SchemaCoding.Support {

  public static func objectProperty<Name: CodingKey, Wrapped>(
    name: Name,
    schema: OptionalSchema<Wrapped>
  ) -> some ObjectProperty<Name, Wrapped.Value?> {
    OptionalObjectProperty(
      name: name,
      schema: schema
    )
  }

  public static func objectProperty<Name: CodingKey, Schema: SchemaCoding.Schema>(
    name: Name,
    schema: Schema
  ) -> some ObjectProperty<Name, Schema.Value> {
    RequiredObjectProperty(
      name: name,
      schema: schema
    )
  }

  public protocol ObjectProperty<Name, Value>: Sendable {
    associatedtype Name: CodingKey
    var name: Name { get }

    var isRequired: Bool { get }

    associatedtype Value
    func encode(_ value: Value, to encoder: inout ObjectPropertiesEncoder)
    associatedtype Decoder: ObjectPropertyDecoder<Schema.Value>
    func beginDecoding(from decoder: borrowing SchemaCoding.Support.Decoder) -> Decoder

    associatedtype Schema: SchemaCoding.Schema where Schema.Value == Value
    var schema: Schema { get }

    associatedtype MetaProperty: ObjectProperty where MetaProperty.Schema.Value == Self
    var metaProperty: MetaProperty { get }
  }

  public protocol ObjectPropertyDecoder<Value> {
    var propertyName: String { get }

    func decode(from decoder: inout Decoder) throws -> DecodingResult<Void>

    associatedtype Value
    func finishDecoding(from decoder: borrowing Decoder) throws -> Value
  }

  private struct RequiredObjectProperty<Name: CodingKey, Schema: SchemaCoding.Schema>:
    PrivateObjectProperty
  {

    var isRequired: Bool {
      true
    }

    func encode(_ value: Schema.Value, to encoder: inout ObjectPropertiesEncoder) {
      encoder.encoder.encodeProperty(name: name.stringValue) { stream in
        stream.encode(value, using: schema)
      }
    }

    func beginDecoding(from decoder: borrowing Decoder) -> ConcreteObjectPropertyDecoder<Self> {
      ConcreteObjectPropertyDecoder(
        property: self,
        reference: decoder.arena.push(.notFound)
      )
    }

    var metaProperty: some ObjectProperty<Name, Self> {
      RequiredObjectProperty<Name, _>(
        name: name,
        schema: schema.metaSchema(in: SchemaContext()).wrap { wrapped in
          Self(name: name, schema: wrapped)
        } unwrap: { property in
          property.schema
        }
      )
    }

    func notFoundValue() throws -> Schema.Value {
      throw Error.missingProperty(name.stringValue)
    }

    let name: Name
    let schema: Schema

  }

  private struct OptionalObjectProperty<Name: CodingKey, Wrapped: SchemaCoding.Schema>:
    PrivateObjectProperty
  {

    typealias Schema = OptionalSchema<Wrapped>

    var isRequired: Bool {
      true
    }

    func encode(_ value: Schema.Value, to encoder: inout ObjectPropertiesEncoder) {
      guard let value else {
        return
      }
      encoder.encoder.encodeProperty(name: name.stringValue) { stream in
        stream.encode(value, using: schema)
      }
    }

    func beginDecoding(from decoder: borrowing Decoder) -> ConcreteObjectPropertyDecoder<Self> {
      ConcreteObjectPropertyDecoder(
        property: self,
        reference: decoder.arena.push(.notFound)
      )
    }

    var metaProperty: some ObjectProperty<Name, Self> {
      /// Use the wrapped schema in the meta-property since `.none` is represented by omission
      RequiredObjectProperty<Name, _>(
        name: name,
        schema: schema.wrapped.metaSchema(in: SchemaContext()).wrap { wrapped in
          Self(name: name, schema: OptionalSchema(wrapped: wrapped))
        } unwrap: { property in
          property.schema.wrapped
        }
      )
    }

    func notFoundValue() throws -> Schema.Value {
      nil
    }

    let name: Name
    let schema: Schema

  }

}

// MARK: - Object Properties Builder

extension SchemaCoding.Support {

  @resultBuilder
  public enum ObjectPropertiesBuilder<Name: CodingKey> {

    public static func buildPartialBlock<First: ObjectProperty>(
      first: First
    ) -> ObjectProperties<Name, First> {
      ObjectProperties(properties: first)
    }

    public static func buildPartialBlock<each Property, Next: ObjectProperty>(
      accumulated: ObjectProperties<Name, repeat each Property>,
      next: Next
    ) -> ObjectProperties<Name, repeat each Property, Next> {
      ObjectProperties(properties: (repeat each accumulated.properties, next))
    }

  }

  public struct ObjectProperties<Name: CodingKey, each Property: ObjectProperty>: Sendable {
    let properties: (repeat each Property)
  }

}

// MARK: - Decoding

extension SchemaCoding.Support {

  fileprivate protocol PrivateObjectProperty: ObjectProperty {
    func notFoundValue() throws -> Value
  }

  fileprivate struct ConcreteObjectPropertyDecoder<
    Property: PrivateObjectProperty
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
    ) throws -> Property.Schema.Value {
      try decoder.arena.withValue(reference) { decodingState in
        switch decodingState {
        case .invalid:
          throw Error.invalidState
        case .decoding:
          throw Error.partiallyDecoded
        case .notFound:
          return try property.notFoundValue()
        case .decoded(let value):
          return value
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

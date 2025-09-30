// MARK: - Properties

extension SchemaCoding.Support {

  public struct ObjectProperty<Name: CodingKey, Schema: SchemaCoding.Support.Schema>:
    ObjectPropertyProtocol
  {

    public init(
      name: Name,
      schema: Schema
    ) {
      self._name = name
      self.isRequired = true
      self.schema = schema
    }

    public init<Wrapped>(
      name: Name,
      schema: OptionalSchema<Wrapped>
    ) where Schema == OptionalPropertySchema<Wrapped> {
      self._name = name
      self.isRequired = false
      self.schema = schema.propertySchema
    }

    fileprivate var name: String { _name.stringValue }
    fileprivate let _name: Name
    fileprivate let isRequired: Bool
    fileprivate let schema: Schema

  }

  fileprivate protocol ObjectPropertyProtocol: Sendable {
    var name: String { get }
    var isRequired: Bool { get }

    func beginDecoding(
      from decoder: inout Decoder
    ) -> any ObjectPropertyDecodingState
  }

  fileprivate protocol ObjectPropertyDecodingState: Sendable {
    associatedtype Value
    func decode(
      from decoder: inout Decoder,
    ) throws -> DecodingResult<Value>
    func finishDecoding(
      from decoder: inout Decoder
    ) throws
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct ObjectSchema<Value>: Schema {

    public struct ValueDecodingState: Sendable {
    }

    public func beginDecodingValue(
      from decoder: inout Decoder
    ) -> ValueDecodingState {
      ValueDecodingState()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> Value {
      fatalError()
    }

    private let properties: [ObjectPropertyProtocol] = []

  }

}

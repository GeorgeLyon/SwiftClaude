import SchemaCodingSupport

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
      self.schema = schema
    }

    fileprivate func beginDecoding(
      in context: inout Decoder.Context
    ) -> some ObjectPropertyDecodingStateReference {
    }

    fileprivate var name: String { _name.stringValue }
    fileprivate let _name: Name
    fileprivate let schema: Schema

  }

  fileprivate protocol ObjectPropertyProtocol: Sendable {
    var name: String { get }

    associatedtype DecodingStateReference: ObjectPropertyDecodingStateReference
    func beginDecoding(in context: inout Decoder.Context) -> DecodingStateReference
  }

  fileprivate protocol ObjectPropertyDecodingStateReference: Sendable {
    func finishDecoding(in context: inout Decoder.Context)
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct ObjectSchema<Value>: Schema {

    public struct ValueDecodingState: Sendable {
      fileprivate var references: [ObjectPropertyDecodingStateReference]
    }

    public func beginDecoding(in context: inout Decoder.Context) -> ValueDecodingState {
      ValueDecodingState()
    }

    public func finishDecoding(
      in context: inout Decoder.Context,
      state: ValueDecodingState
    ) {

    }

    public func decodeInitialValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) -> DecodingResult<Value> {
      fatalError()
    }

    public func decodeStreamingValue<Root>(
      from decoder: inout Decoder,
      root: Root,
      keyPath: WritableKeyPath<Root, Value>,
      state: inout ValueDecodingState
    ) async throws {
      fatalError()
    }

    private let properties: [ObjectPropertyProtocol] = []

  }

}

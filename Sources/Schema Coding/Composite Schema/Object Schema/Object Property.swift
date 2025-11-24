import JSONSupport
import SchemaCodingSupport

extension SchemaCoding.Support {

  public struct ObjectProperty<Name: CodingKey, Schema: SchemaCoding.Schema>:
    ObjectPropertyProtocol
  {

    public init<Wrapped>(
      context: inout SchemaContext,
      name: Name,
      schema: OptionalSchema<Wrapped>
    )
    where
      Schema.Value: BitwiseCopyable,
      Schema.ValueDecodingState: BitwiseCopyable,
      Schema == OptionalPropertySchema<Wrapped>
    {
      self._name = name
      self.optionalMetadata = OptionalMetadata()
      self.schema = OptionalPropertySchema(wrapped: schema.wrapped)
      self.decodingStateReference = context.arenaArchetype.allocate(DecodingState?.self)
    }

    public init(
      context: inout SchemaContext,
      name: Name,
      schema: Schema
    )
    where
      Schema.Value: BitwiseCopyable,
      Schema.ValueDecodingState: BitwiseCopyable
    {
      self._name = name
      self.optionalMetadata = nil
      self.schema = schema
      self.decodingStateReference = context.arenaArchetype.allocate(DecodingState?.self)
    }

    public init<Wrapped>(
      context: inout SchemaContext,
      name: Name,
      schema: OptionalSchema<Wrapped>
    ) where Schema == OptionalPropertySchema<Wrapped> {
      self._name = name
      self.optionalMetadata = OptionalMetadata()
      self.schema = OptionalPropertySchema(wrapped: schema.wrapped)
      self.decodingStateReference = context.arenaArchetype.allocate(DecodingState?.self)
    }

    public init(
      context: inout SchemaContext,
      name: Name,
      schema: Schema
    ) {
      self._name = name
      self.optionalMetadata = nil
      self.schema = schema
      self.decodingStateReference = context.arenaArchetype.allocate(DecodingState?.self)
    }

    var name: String { _name.stringValue }

    func encode(_ value: Schema.Value, to encoder: inout JSON.ObjectEncoder) {
      if let optionalMetadata,
        optionalMetadata.shouldOmit(value)
      {
        return
      } else {
        encoder.encodeProperty(name: name) { stream in
          var encoder = Encoder(stream: stream)
          schema.encode(value, to: &encoder)
          stream = encoder.stream
        }
      }
    }

    func decodeValue(
      from decoder: inout Decoder
    ) throws -> DecodingResult<Void> {
      try decoder.arena.withValue(decodingStateReference) { decodingState in
        var state: Schema.ValueDecodingState
        do {
          switch decodingState {
          case .none:
            state = schema.initialValueDecodingState
          case .decoded:
            throw Error.propertyAlreadyDecoded
          case .decoding(let partialState):
            state = partialState
          case .uninitialized:
            throw Error.invalidState
          }
          decodingState = .uninitialized
        }

        switch try schema.decodeValue(from: &decoder, state: &state).kind {
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
      _ decoder: borrowing Decoder
    ) throws -> Schema.Value {
      switch decoder.arena[decodingStateReference] {
      case .uninitialized:
        throw Error.invalidState
      case .decoding:
        throw Error.partiallyDecoded
      case .decoded(let value):
        return value
      case .none:
        guard let optionalMetadata else {
          throw Error.missingProperty
        }
        return optionalMetadata.valueWhenOmitted()
      }
    }

    var isOptional: Bool {
      optionalMetadata != nil
    }

    fileprivate enum DecodingState {
      case decoding(Schema.ValueDecodingState)
      case decoded(Schema.Value)
      case uninitialized
    }

    private struct OptionalMetadata {
      init<Wrapped>() where Schema == OptionalPropertySchema<Wrapped> {
        self.valueWhenOmitted = { nil }
        self.shouldOmit = { $0 == nil }
      }
      let valueWhenOmitted: @Sendable () -> Schema.Value
      let shouldOmit: @Sendable (Schema.Value) -> Bool
    }

    private let _name: Name
    private let schema: Schema
    private let optionalMetadata: OptionalMetadata?
    private let decodingStateReference: Arena.Reference<DecodingState?>

  }

  protocol ObjectPropertyProtocol: Sendable {
    var name: String { get }

    func decodeValue(
      from decoder: inout Decoder
    ) throws -> DecodingResult<Void>
  }

  public struct OptionalPropertySchema<Wrapped: Schema>: Schema {
    public typealias Value = Wrapped.Value?

    public typealias ValueDecodingState = Wrapped.ValueDecodingState

    public var initialValueDecodingState: ValueDecodingState {
      wrapped.initialValueDecodingState
    }

    public func encode(
      _ value: Wrapped.Value?,
      to encoder: inout SchemaCoding.Support.Encoder
    ) {
      guard let value else {
        /// Null values should be omitted when a property is optional
        assertionFailure()
        encoder.stream.encodeNull()
        return
      }
      wrapped.encode(value, to: &encoder)
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Wrapped.Value?> {
      switch try wrapped.decodeValue(from: &decoder, state: &state).kind {
      case .incomplete:
        .incomplete
      case .decoded(let value):
        .decoded(value)
      }
    }

    let wrapped: Wrapped

  }

}

// MARK: - Implementation Details

private enum Error: Swift.Error {
  case invalidState
  case propertyAlreadyDecoded
  case partiallyDecoded
  case missingProperty
}

extension SchemaCoding.Support.ObjectProperty.DecodingState: BitwiseCopyable
where Schema.ValueDecodingState: BitwiseCopyable, Schema.Value: BitwiseCopyable {

}

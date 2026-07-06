private import JavaScriptObjectNotation

// MARK: - Definition

public struct StructuredTuple<each Element: StructuredDecodable> {

  public let values: (repeat each Element)

  public init(_ values: repeat each Element) {
    self.values = (repeat each values)
  }

}

// MARK: - Conformances

extension StructuredTuple: Sendable where repeat each Element: Sendable {}

extension StructuredTuple: Equatable where repeat each Element: Equatable {

  public static func == (lhs: Self, rhs: Self) -> Bool {
    for (lhs, rhs) in repeat (each lhs.values, each rhs.values) {
      guard lhs == rhs else { return false }
    }
    return true
  }

}

// MARK: - Schema

extension StructuredTuple {

  public static func schema(description: String?) -> StructuredTupleSchema {
    StructuredTupleSchema(
      description: description,
      elements: repeat (each Element).self
    )
  }

}

// MARK: - Encoding

extension StructuredTuple: StructuredEncodable where repeat each Element: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeArray { arrayEncoder in
      for element in repeat each values {
        try arrayEncoder.encodeElement { stream in
          try stream.withEncoder { encoder in
            try element.encode(to: &encoder)
          }
        }
      }
    }
  }

}

// MARK: - Decoding

extension StructuredTuple: StructuredDecodable {

  /// Tuples are not streamable: there is no way to address an individual element
  /// mid-stream, so no value is observable until every element has been decoded.
  public static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    try await context.withArena { arena in
      let stateRefs =
        (repeat arena.push(TupleElementDecodingState<each Element>.pending).unsafePointer)

      try await decoder.stream.decodeArray { arrayDecoder in
        for stateRef in repeat each stateRefs {
          guard !arrayDecoder.isAtEnd else {
            throw TupleDecodingError.tooFewElements
          }
          try await arrayDecoder.decodeElement { stream in
            try await stream.withDecoder { decoder in
              try await stateRef.pointee.decode(from: &decoder, in: context)
            }
          }
        }
        guard arrayDecoder.isAtEnd else {
          throw TupleDecodingError.tooManyElements
        }
      }

      try await accessor.initializeValue(
        to: StructuredTuple(repeat try (each stateRefs).pointee.takeDecodedValue())
      )
    }
  }

}

// MARK: - Element Decoding State

private enum TupleElementDecodingState<Element: StructuredDecodable>: ~Copyable {

  /// The element has not been decoded yet.
  case pending

  /// The element has been fully decoded.
  case decoded(Sending<Element>)

  mutating func decode(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext
  ) async throws {
    let value = try await Element.decode(from: &decoder, in: context)
    self = .decoded(Sending(value))
  }

  /// Moves the decoded element out, leaving the state `pending`.
  mutating func takeDecodedValue() throws -> sending Element {
    switch consume self {
    case .pending:
      self = .pending
      throw TupleDecodingError.elementNotDecoded
    case .decoded(let value):
      self = .pending
      return value.send()
    }
  }

}

// MARK: - Errors

private enum TupleDecodingError: Error {
  case tooFewElements
  case tooManyElements
  case elementNotDecoded
}

// MARK: - Tuple Schema

public struct StructuredTupleSchema {

  init<each Element: StructuredDecodable>(
    description: String?,
    elements: repeat (each Element).Type
  ) {
    self.description = description

    do {
      var mutablePrefixItems: [Result<OpaqueValue, Error>] = []
      for element in repeat each elements {
        mutablePrefixItems.append(
          Result {
            try OpaqueValue(element.schema())
          }
        )
      }
      self.prefixItems = mutablePrefixItems
    }
  }

  private let description: String?

  private let prefixItems: [Result<OpaqueValue, Error>]

}

// MARK: Schema

extension StructuredTupleSchema {

  public static func schema(
    description: String?
  ) -> StructuredAnySchema {
    StructuredAnySchema(description: nil)
  }

}

// MARK: Encoding

extension StructuredTupleSchema: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeObject { objectEncoder in
      if let description {
        objectEncoder.encodeProperty(.description) { stream in
          stream.encode(description)
        }
      }
      try objectEncoder.encodeProperty(.prefixItems) { stream in
        try stream.encodeArray { arrayEncoder in
          for prefixItem in prefixItems {
            let schema = try prefixItem.get()
            arrayEncoder.encodeElement { stream in
              stream.encode(schema)
            }
          }
        }
      }
    }
  }

}

extension EncodingStream.ObjectEncoder {

  fileprivate mutating func encodeProperty(
    _ name: SchemaPropertyName,
    encodeValue: (inout EncodingStream) throws -> Void
  ) rethrows {
    try encodeProperty(name.rawValue, encodeValue: encodeValue)
  }

}

// MARK: Decoding

extension StructuredTupleSchema: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending StructuredTupleSchema? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let schema = try await decoder.stream.decodeObject { objectDecoder in
      var description: String?
      var prefixItems: [Result<OpaqueValue, Error>]?
      while !objectDecoder.isAtEnd {
        try await objectDecoder.decodeSchemaProperty { name, stream in
          switch name {
          case .description:
            guard description == nil else {
              throw TupleSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            description = try await stream.decodeString()
          case .prefixItems:
            guard prefixItems == nil else {
              throw TupleSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            prefixItems = try await stream.decodeArrayElements { stream in
              Result.success(try await stream.decodeOpaqueValue())
            }
          }
        }
      }
      guard let prefixItems else {
        throw TupleSchemaDecodingError.propertyNotFound(SchemaPropertyName.prefixItems.rawValue)
      }
      return StructuredTupleSchema(description: description, prefixItems: prefixItems)
    }
    try await accessor.initializeValue(to: schema)
  }

  private init(description: String?, prefixItems: [Result<OpaqueValue, Error>]) {
    self.description = description
    self.prefixItems = prefixItems
  }

}

private enum TupleSchemaDecodingError: Error {
  case unknownPropertyName(String)
  case duplicateProperty(String)
  case propertyNotFound(String)
}

extension DecodingStream.ObjectDecoder {

  fileprivate mutating func decodeSchemaProperty<T>(
    decodeValue: (SchemaPropertyName, inout DecodingStream) async throws -> sending T
  ) async throws -> sending T {
    try await decodeProperty(
      decodeName: { stream in
        let rawValue = try await stream.decodeString()
        guard let name = SchemaPropertyName(rawValue: rawValue) else {
          throw TupleSchemaDecodingError.unknownPropertyName(rawValue)
        }
        return name
      },
      decodeValue: decodeValue
    )
  }

}

// MARK: Property Names

private enum SchemaPropertyName: String {
  case description
  case prefixItems
}

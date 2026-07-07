private import JavaScriptObjectNotation

// MARK: - Definition

public struct StructuredOneOfSchema {

  init<each Subschema: StructuredEncodable>(
    description: String?,
    subschemas: repeat each Subschema
  ) {
    self.description = description

    do {
      var mutableOneOf: [Result<OpaqueValue, Error>] = []
      for subschema in repeat each subschemas {
        mutableOneOf.append(
          Result {
            try OpaqueValue(subschema)
          }
        )
      }
      self.oneOf = mutableOneOf
    }
  }

  private let description: String?

  private let oneOf: [Result<OpaqueValue, Error>]

}

// MARK: - Schema

extension StructuredOneOfSchema {

  public static func schema(
    description: String?
  ) -> StructuredAnySchema {
    StructuredAnySchema(description: nil)
  }

}

// MARK: - Encoding

extension StructuredOneOfSchema: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeObject { objectEncoder in
      if let description {
        objectEncoder.encodeProperty(.description) { stream in
          stream.encode(description)
        }
      }
      try objectEncoder.encodeProperty(.oneOf) { stream in
        try stream.encodeArray { arrayEncoder in
          for subschema in oneOf {
            let schema = try subschema.get()
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

// MARK: - Decoding

extension StructuredOneOfSchema: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending StructuredOneOfSchema? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let schema = try await decoder.stream.decodeObject { objectDecoder in
      var description: String?
      var oneOf: [Result<OpaqueValue, Error>]?
      while !objectDecoder.isAtEnd {
        try await objectDecoder.decodeSchemaProperty { name, stream in
          switch name {
          case .description:
            guard description == nil else {
              throw OneOfSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            description = try await stream.decodeString()
          case .oneOf:
            guard oneOf == nil else {
              throw OneOfSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            let decoded: [Result<OpaqueValue, Error>] = try await stream.decodeArrayElements {
              stream in
              .success(try await stream.decodeOpaqueValue())
            }
            guard !decoded.isEmpty else {
              throw OneOfSchemaDecodingError.emptyOneOfArray
            }
            oneOf = decoded
          }
        }
      }
      guard let oneOf else {
        throw OneOfSchemaDecodingError.propertyNotFound(SchemaPropertyName.oneOf.rawValue)
      }
      return StructuredOneOfSchema(description: description, oneOf: oneOf)
    }
    try await accessor.initializeValue(to: schema)
  }

  private init(description: String?, oneOf: [Result<OpaqueValue, Error>]) {
    self.description = description
    self.oneOf = oneOf
  }

}

private enum OneOfSchemaDecodingError: Error {
  case emptyOneOfArray
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
          throw OneOfSchemaDecodingError.unknownPropertyName(rawValue)
        }
        return name
      },
      decodeValue: decodeValue
    )
  }

}

// MARK: - Property Names

private enum SchemaPropertyName: String {
  case description
  case oneOf
}

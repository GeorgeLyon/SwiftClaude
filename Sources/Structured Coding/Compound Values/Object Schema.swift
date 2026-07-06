private import JavaScriptObjectNotation

// MARK: - Definition

public struct StructuredObjectSchema {

  init<Value, each PropertyDefinition>(
    description: String?,
    valueProperties: repeat StructuredObjectProperty<
      Value,
      each PropertyDefinition
    >
  ) {
    self.description = description
    self.maxProperties = nil

    do {
      var mutableProperties: [Property] = []
      var mutableRequired: [String] = []
      for property in repeat each valueProperties {
        mutableProperties.append(
          Property(
            name: property.name.stringValue,
            schemaEncodingResult: Result {
              try OpaqueValue(property.schema)
            }
          )
        )
        if property.isRequired {
          mutableRequired.append(property.name.stringValue)
        }
      }
      self.properties = mutableProperties
      self.required = mutableRequired
    }
  }

  /// The schema of an enumeration coded as object properties: one property per
  /// case, none required, with `maxProperties: 1` enforcing that exactly one
  /// case is present.
  init<each CaseSchema: StructuredEncodable>(
    description: String?,
    caseSchemas: repeat (StructuredCodingKey, each CaseSchema)
  ) {
    self.description = description
    self.maxProperties = 1

    do {
      var mutableProperties: [Property] = []
      for (name, schema) in repeat each caseSchemas {
        mutableProperties.append(
          Property(
            name: name.stringValue,
            schemaEncodingResult: Result {
              try OpaqueValue(schema)
            }
          )
        )
      }
      self.properties = mutableProperties
      self.required = []
    }
  }

  private let description: String?

  /// The name is a `String` rather than a `StructuredCodingKey` because
  /// decoded schemas have dynamic property names.
  private struct Property {
    let name: String
    let schemaEncodingResult: Result<OpaqueValue, Error>
  }
  private let properties: [Property]

  private let required: [String]

  private let maxProperties: Int?

}

// MARK: - Schema

extension StructuredObjectSchema {

  public static func schema(
    description: String?
  ) -> StructuredAnySchema {
    StructuredAnySchema(description: nil)
  }

}

// MARK: - Encoding

extension StructuredObjectSchema: StructuredEncodable {

  public func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeObject { objectEncoder in
      if let description {
        objectEncoder.encodeProperty(.description) { stream in
          stream.encode(description)
        }
      }
      try objectEncoder.encodeProperty(.properties) { stream in
        try stream.encodeObject { propertiesEncoder in
          for property in properties {
            let schema = try property.schemaEncodingResult.get()
            propertiesEncoder.encodeProperty(property.name) { stream in
              stream.encode(schema)
            }
          }
        }
      }
      if !required.isEmpty {
        objectEncoder.encodeProperty(.required) { stream in
          stream.encodeArray { arrayEncoder in
            for name in required {
              arrayEncoder.encodeElement { stream in
                stream.encode(name)
              }
            }
          }
        }
      }
      if let maxProperties {
        objectEncoder.encodeProperty(.maxProperties) { stream in
          stream.encode(maxProperties)
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

extension StructuredObjectSchema: StructuredDecodable {

  public static func initialValueForDecoding(isMutable: Bool) -> sending StructuredObjectSchema? {
    nil
  }

  public static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let schema = try await decoder.stream.decodeObject { objectDecoder in
      var description: String?
      var properties: [Property]?
      var required: [String]?
      var maxProperties: Int?
      while !objectDecoder.isAtEnd {
        try await objectDecoder.decodeSchemaProperty { name, stream in
          switch name {
          case .description:
            guard description == nil else {
              throw ObjectSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            description = try await stream.decodeString()
          case .properties:
            guard properties == nil else {
              throw ObjectSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            properties = try await stream.decodeObject { propertiesDecoder in
              var properties: [Property] = []
              while !propertiesDecoder.isAtEnd {
                properties.append(
                  try await propertiesDecoder.decodeProperty { name, stream in
                    Property(
                      name: name,
                      schemaEncodingResult: .success(try await stream.decodeOpaqueValue())
                    )
                  }
                )
              }
              return properties
            }
          case .required:
            guard required == nil else {
              throw ObjectSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            let decoded = try await stream.decodeArrayElements { stream in
              try await stream.decodeString()
            }
            guard !decoded.isEmpty else {
              throw ObjectSchemaDecodingError.emptyRequiredArray
            }
            required = decoded
          case .maxProperties:
            guard maxProperties == nil else {
              throw ObjectSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            maxProperties = try await stream.decodeNumber().decode(as: Int.self)
          }
        }
      }
      guard let properties else {
        throw ObjectSchemaDecodingError.propertyNotFound(SchemaPropertyName.properties.rawValue)
      }
      return StructuredObjectSchema(
        description: description,
        properties: properties,
        required: required ?? [],
        maxProperties: maxProperties
      )
    }
    try await accessor.initializeValue(to: schema)
  }

  private init(
    description: String?,
    properties: [Property],
    required: [String],
    maxProperties: Int?
  ) {
    self.description = description
    self.properties = properties
    self.required = required
    self.maxProperties = maxProperties
  }

}

private enum ObjectSchemaDecodingError: Error {
  case emptyRequiredArray
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
          throw ObjectSchemaDecodingError.unknownPropertyName(rawValue)
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
  case properties
  case required
  case maxProperties
}

internal import JavaScriptObjectNotation

// MARK: - Definition

/// The single concrete type behind every `schema(description:)` witness in the
/// module. Public API only ever exposes it as `some StructuredCodable`; which
/// JSON-schema keywords a value carries is determined by the factory that
/// built it. Kept non-generic so witness manglings never contain pack
/// expansions (which crash the runtime demangler).
struct MetaSchema {

  /// The name is a `String` rather than a `StructuredCodingKey` because
  /// decoded schemas have dynamic property names.
  struct Property {
    let name: String
    let schemaEncodingResult: Result<OpaqueValue, Error>
  }

  private let description: String?
  private let type: String?
  private let items: Result<OpaqueValue, Error>?
  private let prefixItems: [Result<OpaqueValue, Error>]?
  private let properties: [Property]?
  private let required: [String]
  private let maxProperties: Int?
  private let oneOf: [Result<OpaqueValue, Error>]?

  private init(
    description: String? = nil,
    type: String? = nil,
    items: Result<OpaqueValue, Error>? = nil,
    prefixItems: [Result<OpaqueValue, Error>]? = nil,
    properties: [Property]? = nil,
    required: [String] = [],
    maxProperties: Int? = nil,
    oneOf: [Result<OpaqueValue, Error>]? = nil
  ) {
    self.description = description
    self.type = type
    self.items = items
    self.prefixItems = prefixItems
    self.properties = properties
    self.required = required
    self.maxProperties = maxProperties
    self.oneOf = oneOf
  }

}

// MARK: - Factories

extension MetaSchema {

  /// The type-erased schema: `{}`, optionally with a description.
  static func any(description: String?) -> MetaSchema {
    MetaSchema(description: description)
  }

  static func string(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "string")
  }

  static func boolean(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "boolean")
  }

  static func integer(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "integer")
  }

  static func number(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "number")
  }

  static func array(
    description: String?,
    items: some StructuredEncodable
  ) -> MetaSchema {
    MetaSchema(
      description: description,
      items: Result { try OpaqueValue(items) }
    )
  }

  static func tuple<each ElementSchema: StructuredEncodable>(
    description: String?,
    prefixItems: repeat each ElementSchema
  ) -> MetaSchema {
    var encodedPrefixItems: [Result<OpaqueValue, Error>] = []
    for prefixItem in repeat each prefixItems {
      encodedPrefixItems.append(
        Result { try OpaqueValue(prefixItem) }
      )
    }
    return MetaSchema(
      description: description,
      prefixItems: encodedPrefixItems
    )
  }

  /// The unified object schema: value properties and enumeration cases both
  /// lower to `(name, schema, isRequired)` triples — a case is simply a
  /// property that is never required (with `maxProperties: 1` limiting the
  /// object to a single case).
  static func object<each PropertySchema: StructuredEncodable>(
    description: String?,
    maxProperties: Int? = nil,
    properties: repeat (StructuredCodingKey, each PropertySchema, Bool)
  ) -> MetaSchema {
    var encodedProperties: [Property] = []
    var required: [String] = []
    for (name, schema, isRequired) in repeat each properties {
      encodedProperties.append(
        Property(
          name: name.stringValue,
          schemaEncodingResult: Result { try OpaqueValue(schema) }
        )
      )
      if isRequired {
        required.append(name.stringValue)
      }
    }
    return MetaSchema(
      description: description,
      properties: encodedProperties,
      required: required,
      maxProperties: maxProperties
    )
  }

  static func oneOf<each Subschema: StructuredEncodable>(
    description: String?,
    subschemas: repeat each Subschema
  ) -> MetaSchema {
    var encodedSubschemas: [Result<OpaqueValue, Error>] = []
    for subschema in repeat each subschemas {
      encodedSubschemas.append(
        Result { try OpaqueValue(subschema) }
      )
    }
    return MetaSchema(
      description: description,
      oneOf: encodedSubschemas
    )
  }

}

// MARK: - Schema

extension MetaSchema {

  /// A schema value's own schema erases to the `{}` any-schema.
  static func schema(description: String?) -> some StructuredCodable {
    MetaSchema.any(description: description)
  }

}

// MARK: - Encoding

extension MetaSchema: StructuredEncodable {

  func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeObject { objectEncoder in
      if let description {
        objectEncoder.encodeProperty(.description) { stream in
          stream.encode(description)
        }
      }
      if let type {
        objectEncoder.encodeProperty(.type) { stream in
          stream.encode(type)
        }
      }
      if let items {
        let schema = try items.get()
        objectEncoder.encodeProperty(.items) { stream in
          stream.encode(schema)
        }
      }
      if let prefixItems {
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
      if let properties {
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
      if let oneOf {
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

}

extension EncodingStream.ObjectEncoder {

  fileprivate mutating func encodeProperty(
    _ name: MetaSchemaPropertyName,
    encodeValue: (inout EncodingStream) throws -> Void
  ) rethrows {
    try encodeProperty(name.rawValue, encodeValue: encodeValue)
  }

}

// MARK: - Decoding

extension MetaSchema: StructuredDecodable {

  static func initialValueForDecoding(isMutable: Bool) -> sending MetaSchema? {
    nil
  }

  static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let schema = try await decoder.stream.decodeObject { objectDecoder in
      var description: String?
      var type: String?
      var items: Result<OpaqueValue, Error>?
      var prefixItems: [Result<OpaqueValue, Error>]?
      var properties: [Property]?
      var required: [String]?
      var maxProperties: Int?
      var oneOf: [Result<OpaqueValue, Error>]?
      while !objectDecoder.isAtEnd {
        try await objectDecoder.decodeSchemaProperty { name, stream in
          switch name {
          case .description:
            guard description == nil else {
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            description = try await stream.decodeString()
          case .type:
            guard type == nil else {
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            type = try await stream.decodeString()
          case .items:
            guard items == nil else {
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            items = .success(try await stream.decodeOpaqueValue())
          case .prefixItems:
            guard prefixItems == nil else {
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            prefixItems = try await stream.decodeArrayElements { stream in
              Result.success(try await stream.decodeOpaqueValue())
            }
          case .properties:
            guard properties == nil else {
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
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
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            let decoded = try await stream.decodeArrayElements { stream in
              try await stream.decodeString()
            }
            guard !decoded.isEmpty else {
              throw MetaSchemaDecodingError.emptyRequiredArray
            }
            required = decoded
          case .maxProperties:
            guard maxProperties == nil else {
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            maxProperties = try await stream.decodeNumber().decode(as: Int.self)
          case .oneOf:
            guard oneOf == nil else {
              throw MetaSchemaDecodingError.duplicateProperty(name.rawValue)
            }
            let decoded: [Result<OpaqueValue, Error>] = try await stream.decodeArrayElements {
              stream in
              .success(try await stream.decodeOpaqueValue())
            }
            guard !decoded.isEmpty else {
              throw MetaSchemaDecodingError.emptyOneOfArray
            }
            oneOf = decoded
          }
        }
      }
      return MetaSchema(
        description: description,
        type: type,
        items: items,
        prefixItems: prefixItems,
        properties: properties,
        required: required ?? [],
        maxProperties: maxProperties,
        oneOf: oneOf
      )
    }
    try await accessor.initializeValue(to: schema)
  }

}

private enum MetaSchemaDecodingError: Error {
  case unknownPropertyName(String)
  case duplicateProperty(String)
  case emptyRequiredArray
  case emptyOneOfArray
}

extension DecodingStream.ObjectDecoder {

  fileprivate mutating func decodeSchemaProperty<T>(
    decodeValue: (MetaSchemaPropertyName, inout DecodingStream) async throws -> sending T
  ) async throws -> sending T {
    try await decodeProperty(
      decodeName: { stream in
        let rawValue = try await stream.decodeString()
        guard let name = MetaSchemaPropertyName(rawValue: rawValue) else {
          throw MetaSchemaDecodingError.unknownPropertyName(rawValue)
        }
        return name
      },
      decodeValue: decodeValue
    )
  }

}

// MARK: - Property Names

private enum MetaSchemaPropertyName: String {
  case description
  case type
  case items
  case prefixItems
  case properties
  case required
  case maxProperties
  case oneOf
}

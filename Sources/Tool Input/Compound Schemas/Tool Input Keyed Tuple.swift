// MARK: - Tool Input

/// There is no corresponding `ToolInput` type for `ToolInputKeyedTupleSchema`.
/// Instead, it is used indirectly to implement `ToolInput` for structured types.

// MARK: - Schema

public struct ToolInputKeyedTupleSchema<
  each Element: ToolInputSchema
>: ToolInputSchema {
  public typealias DescribedValue = (repeat (each Element).DescribedValue)

  public var elements: (repeat each Element)
  public var description: String?
  public init(
    description: String? = nil,
    _ elements: repeat (key: ToolInputSchemaKey, schema: each Element)
  ) {
    ToolInputSchemaKey.assertAllKeysUniqueIn((repeat (each elements, (each elements).key)))
    self.elements = (repeat (each elements).schema)
    self.elementMetadata =
      (repeat (
        type: type(of: (each elements).schema),
        key: (each elements).key.codingKey
      ))
    self.description = description
  }

  public func decodeValue(from decoder: ToolInputDecoder) throws -> DescribedValue {
    let container = try decoder.decoder.container(keyedBy: ToolInputSchemaKey.CodingKey.self)
    return
      (repeat try (each elements).decodeValue(
        from: .init(
          decoder: container.superDecoder(
            forKey: (each elementMetadata).key
          )
        )
      ))
  }

  public func encode(_ values: DescribedValue, to encoder: ToolInputEncoder) throws {
    var container = encoder.encoder.container(keyedBy: ToolInputSchemaKey.CodingKey.self)
    repeat try (each elements).encode(
      (each values),
      to: container.superEncoder(
        forKey: (each elementMetadata).key
      )
    )
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: ContainerCodingKey.self)
    try container.encode("object", forKey: .type)
    try container.encodeIfPresent(description, forKey: .description)
    var required: [String] = []

    do {
      var container = container.nestedContainer(
        keyedBy: ToolInputSchemaKey.CodingKey.self,
        forKey: .properties
      )
      for (schema, metadata) in repeat (each elements, each elementMetadata) {
        if schema.metadata.nullValue == nil {
          required.append(metadata.key.stringValue)
        }
        let encoder = container.superEncoder(forKey: metadata.key)
        try schema.encode(to: encoder)
      }
    }

    try container.encode(false, forKey: .additionalProperties)

    if !required.isEmpty {
      /// An empty `required` array is invalid in JSONSchema
      /// https://json-schema.org/understanding-json-schema/reference/object#required
      try container.encode(required, forKey: .required)
    }
  }

  private let elementMetadata:
    (
      repeat (
        type: (each Element).Type,
        key: ToolInputSchemaKey.CodingKey
      )
    )
}

// MARK: - Implementation Details

private enum ContainerCodingKey: Swift.CodingKey {
  case type
  case description
  case properties
  case additionalProperties
  case required
}

extension KeyedDecodingContainer {
  fileprivate func decodeValue<Schema: ToolInputSchema>(
    conformingTo schema: Schema,
    forKey key: Key
  ) throws -> Schema.DescribedValue {
    if let nullValue = schema.metadata.nullValue,
      !contains(key)
    {
      return nullValue
    } else {
      return try schema.decodeValue(from: superDecoder(forKey: key))
    }
  }
}

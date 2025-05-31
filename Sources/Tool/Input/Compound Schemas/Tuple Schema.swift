extension ToolInput {

  // Needs to be disfavored because otherwise it catches single-element tuples
  @_disfavoredOverload
  public static func schema<each Element: ToolInput.SchemaCodable>(
    representing _: (repeat each Element).Type = (repeat each Element).self
  ) -> some Schema<(repeat each Element)> {
    TupleSchema(
      elements: (repeat (
        name: String?.none,
        schema: (each Element).toolInputSchema
      ))
    )
  }

}

// MARK: - Implementation Details

/// A schema for ordered collection of typed values
/// Also used for enum associated values
struct TupleSchema<each ElementSchema: ToolInput.Schema>: InternalSchema {

  typealias Value = (repeat (each ElementSchema).Value)

  let elements:
    (
      repeat
        (
          name: String?,
          schema: each ElementSchema
        )
    )

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)
    try container.encode("array", forKey: .type)

    if let description = encoder.contextualDescription(nil) {
      try container.encode(description, forKey: .description)
    }

    /// No additional items
    try container.encode(false, forKey: .items)

    var itemsCount = 0

    var prefixItems = container.nestedUnkeyedContainer(forKey: .prefixItems)
    for element in repeat each elements {
      itemsCount += 1

      try element.schema.encodeSchemaDefinition(
        to: ToolInput.SchemaEncoder(
          wrapped: prefixItems.superEncoder(),
          descriptionPrefix: element.name
        )
      )
    }

    try container.encode(itemsCount, forKey: .minItems)
  }

  func encodeSchemaDefinition(to encoder: inout ToolInput.NewSchemaEncoder<Self>) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      /// This is implied by `prefixItems`, and we're being economic with tokens.
      // encoder.encodeProperty(name: "type") { $0.encode("array") }

      encoder.encodeProperty(name: "prefixItems") { stream in
        stream.encodeArray { encoder in
          for element in repeat each elements {
            encoder.encodeElement { encoder in
              encoder.encodeSchemaDefinition(
                element.schema,
                descriptionPrefix: element.name
              )
            }
          }
        }
      }
    }
  }

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    var container = encoder.wrapped.unkeyedContainer()
    repeat try (each elements).schema.encode(
      each value,
      to: ToolInput.Encoder(wrapped: container.superEncoder())
    )
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    var container = try decoder.wrapped.unkeyedContainer()
    return try
      (repeat (each elements).schema.decodeValue(
        from: ToolInput.Decoder(wrapped: container.superDecoder())
      ))
  }

}

private enum SchemaCodingKey: Swift.CodingKey {
  case type
  case description
  case prefixItems
  case minItems
  case items
}

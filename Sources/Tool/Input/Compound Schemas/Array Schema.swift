extension ToolInput {

  public static func schema<Element: ToolInput.SchemaCodable>(
    representing: [Element].Type = [Element].self
  ) -> some ToolInput.Schema<[Element]> {
    ArraySchema(elementSchema: Element.toolInputSchema)
  }

}

extension Array: ToolInput.SchemaCodable where Element: ToolInput.SchemaCodable {

  public static var toolInputSchema: some ToolInput.Schema<Self> {
    ToolInput.schema()
  }

}

// MARK: - Schema

private struct ArraySchema<ElementSchema: ToolInput.Schema>: InternalSchema {

  typealias Value = [ElementSchema.Value]

  let elementSchema: ElementSchema

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)
    try container.encode("array", forKey: .type)

    if let description = encoder.contextualDescription(nil) {
      try container.encode(description, forKey: .description)
    }

    try elementSchema.encodeSchemaDefinition(
      to: ToolInput.SchemaEncoder(
        wrapped: container.superEncoder(forKey: .items)
      )
    )
  }
  
  func encodeSchemaDefinition(to encoder: inout ToolInput.NewSchemaEncoder<Self>) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      encoder.encodeProperty(name: "type") { $0.encode("array") }
      
      encoder.encodeProperty(name: "items") { stream in
        stream.encodeSchemaDefinition(elementSchema)
      }
    }
  }

  func encode(_ values: Value, to encoder: ToolInput.Encoder<Self>) throws {
    var container = encoder.wrapped.unkeyedContainer()
    for value in values {
      try elementSchema.encode(
        value,
        to: ToolInput.Encoder(
          wrapped: container.superEncoder()
        )
      )
    }
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    var container = try decoder.wrapped.unkeyedContainer()
    var elements: Value = []
    if let count = container.count {
      elements.reserveCapacity(count)
    }
    while !container.isAtEnd {
      elements.append(
        try elementSchema.decodeValue(
          from: ToolInput.Decoder(
            wrapped: container.superDecoder()
          )
        )
      )
    }
    return elements
  }

}

private enum SchemaCodingKey: CodingKey {
  case type, description, items
}

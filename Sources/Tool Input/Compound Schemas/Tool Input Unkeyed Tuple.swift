// MARK: - Tool Input

/// `ToolInputVoidSchema` is not used to implement a `ToolInput` because Swift does not yet have generalized tuple confirmances.

// MARK: - Schema

public struct ToolInputUnkeyedTupleSchema<
  each Element: ToolInputSchema
>: ToolInputSchema {
  public typealias DescribedValue = (repeat (each Element).DescribedValue)

  public var elements: (repeat each Element)
  public var description: String?

  public init(
    description: String? = nil,
    _ elements: repeat each Element
  ) {
    self.elements = (repeat each elements)
    self.description = description
  }

  public func decodeValue(from decoder: ToolInputDecoder) throws -> DescribedValue {
    var container = try decoder.decoder.unkeyedContainer()
    return try (repeat (each elements).decodeValue(from: .init(decoder: container.superDecoder())))
  }

  public func encode(_ values: DescribedValue, to encoder: ToolInputEncoder) throws {
    var container = encoder.encoder.unkeyedContainer()
    repeat try (each elements).encode((each values), to: .init(encoder: container.superEncoder()))
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: ContainerCodingKey.self)
    try container.encode("array", forKey: .type)
    try container.encodeIfPresent(description, forKey: .description)

    var prefixItemsContainer = container.nestedUnkeyedContainer(forKey: .prefixItems)
    repeat try (each elements).encode(to: prefixItemsContainer.superEncoder())

    // Ensure no additional items are allowed
    try container.encode(false, forKey: .items)

    // Enforce the exact number of items
    try container.encode(prefixItemsContainer.count, forKey: .minItems)
    try container.encode(prefixItemsContainer.count, forKey: .maxItems)
  }
}

// MARK: - Implementation Details

private enum ContainerCodingKey: String, CodingKey {
  case type, description, prefixItems, items, minItems, maxItems
}

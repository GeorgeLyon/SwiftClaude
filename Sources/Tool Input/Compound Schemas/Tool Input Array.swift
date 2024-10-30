// MARK: - Tool Input

extension Array: ToolInput where Element: ToolInput {
  public typealias ToolInputSchema = ToolInputArraySchema<Element.ToolInputSchema>

  public static var toolInputSchema: ToolInputSchema {
    ToolInputArraySchema(element: Element.toolInputSchema)
  }

  public init(
    toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue
  ) throws {
    self = try toolInputSchemaDescribedValue.map(Element.init)
  }

  public var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
    map(\.toolInputSchemaDescribedValue)
  }
}

// MARK: - Schema

public struct ToolInputArraySchema<ElementSchema: ToolInputSchema>: ToolInputSchema {

  public typealias DescribedValue = [ElementSchema.DescribedValue]

  public init(
    element: ElementSchema,
    description: String? = nil,
    maxItems: Int? = nil,
    minItems: Int? = nil,
    uniqueItems: Bool = false
  ) {
    self.element = element
    self.description = description
    self.maxItems = maxItems
    self.minItems = minItems
    self.uniqueItems = uniqueItems
  }

  public var element: ElementSchema
  public var description: String?
  public var maxItems: Int?
  public var minItems: Int?
  public var uniqueItems = false

  public func decodeValue(
    from decoder: ToolInputDecoder
  ) throws -> [ElementSchema.DescribedValue] {
    var container = try decoder.decoder.unkeyedContainer()
    var elements: DescribedValue = []
    if let count = container.count {
      elements.reserveCapacity(count)
    }
    while !container.isAtEnd {
      elements.append(try element.decodeValue(from: .init(decoder: container.superDecoder())))
    }
    return elements
  }

  public func encode(_ values: DescribedValue, to encoder: ToolInputEncoder) throws {
    var container = encoder.encoder.unkeyedContainer()
    for value in values {
      try element.encode(value, to: container.superEncoder())
    }
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: CodingKey.self)
    try container.encode("array", forKey: .type)
    try element.encode(to: container.superEncoder(forKey: .items))
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(minItems, forKey: .minItems)
    try container.encodeIfPresent(maxItems, forKey: .maxItems)
    if uniqueItems { try container.encode(true, forKey: .uniqueItems) }
  }
}

private enum CodingKey: Swift.CodingKey {
  case type, description, items, minItems, maxItems, uniqueItems
}

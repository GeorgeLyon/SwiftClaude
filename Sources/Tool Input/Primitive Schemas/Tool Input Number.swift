// MARK: - Tool Input

extension Float: ToolInput {
  public static var toolInputSchema: ToolInputNumberSchema<Self> { ToolInputNumberSchema() }
}

extension Double: ToolInput {
  public static var toolInputSchema: ToolInputNumberSchema<Self> { ToolInputNumberSchema() }
}

// MARK: - Schema

public struct ToolInputNumberSchema<DescribedValue: FloatingPoint & Codable>:
  ToolInputSchema
{

  public var description: String?
  public var minimum: DescribedValue?
  public var maximum: DescribedValue?
  public var exclusiveMinimum: DescribedValue?
  public var exclusiveMaximum: DescribedValue?
  public var multipleOf: DescribedValue?

  public init(
    description: String? = nil,
    minimum: DescribedValue? = nil,
    maximum: DescribedValue? = nil,
    exclusiveMinimum: DescribedValue? = nil,
    exclusiveMaximum: DescribedValue? = nil,
    multipleOf: DescribedValue? = nil
  ) {
    self.description = description
    self.minimum = minimum
    self.maximum = maximum
    self.exclusiveMinimum = exclusiveMinimum
    self.exclusiveMaximum = exclusiveMaximum
    self.multipleOf = multipleOf
  }

  public func decodeValue(
    from decoder: ToolInputDecoder
  ) throws -> DescribedValue {
    return try decoder.decoder.singleValueContainer().decode(DescribedValue.self)
  }

  public func encode(_ value: DescribedValue, to encoder: ToolInputEncoder) throws {
    var container = encoder.encoder.singleValueContainer()
    try container.encode(value)
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: CodingKey.self)
    try container.encode("number", forKey: .type)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(minimum, forKey: .minimum)
    try container.encodeIfPresent(maximum, forKey: .maximum)
    try container.encodeIfPresent(exclusiveMinimum, forKey: .exclusiveMinimum)
    try container.encodeIfPresent(exclusiveMaximum, forKey: .exclusiveMaximum)
    try container.encodeIfPresent(multipleOf, forKey: .multipleOf)
  }

  public var metadata: ToolInputSchemaMetadata<ToolInputNumberSchema> {
    let properties: [Any?] = [
      description,
      minimum,
      maximum,
      exclusiveMinimum,
      exclusiveMaximum,
      multipleOf,
    ]
    return ToolInputSchemaMetadata(
      primitiveRepresentation: properties.allSatisfy { $0 != nil } ? "number" : nil
    )
  }
}

private enum CodingKey: Swift.CodingKey {
  case type, description, minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf
}

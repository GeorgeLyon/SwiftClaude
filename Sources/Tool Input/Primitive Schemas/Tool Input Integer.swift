// MARK: - Tool Input

extension Int: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

extension Int8: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

extension Int32: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

extension Int64: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

extension UInt: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

extension UInt8: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

extension UInt32: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

extension UInt64: ToolInput {
  public static var toolInputSchema: ToolInputIntegerSchema<Self> { ToolInputIntegerSchema() }
}

// MARK: - Schema

public struct ToolInputIntegerSchema<DescribedValue: BinaryInteger & Codable & Sendable>:
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
    try container.encode("integer", forKey: .type)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(minimum, forKey: .minimum)
    try container.encodeIfPresent(maximum, forKey: .maximum)
    try container.encodeIfPresent(exclusiveMinimum, forKey: .exclusiveMinimum)
    try container.encodeIfPresent(exclusiveMaximum, forKey: .exclusiveMaximum)
    try container.encodeIfPresent(multipleOf, forKey: .multipleOf)
  }

  public var metadata: ToolInputSchemaMetadata<ToolInputIntegerSchema> {
    let properties: [Any?] = [
      description,
      minimum,
      maximum,
      exclusiveMinimum,
      exclusiveMaximum,
      multipleOf,
    ]
    return ToolInputSchemaMetadata(
      primitiveRepresentation: properties.allSatisfy { $0 != nil } ? "integer" : nil
    )
  }
}

private enum CodingKey: Swift.CodingKey {
  case type, description, minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf
}

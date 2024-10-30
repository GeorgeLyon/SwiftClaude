// MARK: - Tool Input

/// `ToolInputVoidSchema` is not used to implement a `ToolInput` because Swift does not yet have generalized tuple confirmances (and `Void` is a 0-element tuple).

// MARK: - Schema

public struct ToolInputVoidSchema: ToolInputSchema {
  public typealias DescribedValue = Void

  public var description: String?

  public init(
    description: String? = nil
  ) {
    self.description = description
  }

  public func decodeValue(from decoder: ToolInputDecoder) throws -> DescribedValue {
    _ = try decoder.decoder.singleValueContainer().decode(EmptyObject.self)
  }

  public func encode(_ values: DescribedValue, to encoder: ToolInputEncoder) throws {
    var container = encoder.encoder.singleValueContainer()
    try container.encode(EmptyObject())
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: ContainerCodingKey.self)
    try container.encode("object", forKey: .type)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encode(false, forKey: .additionalProperties)
  }
}

// MARK: - Implementation Details

private struct EmptyObject: Codable {

}

private enum ContainerCodingKey: Swift.CodingKey {
  case type
  case description
  case additionalProperties
}

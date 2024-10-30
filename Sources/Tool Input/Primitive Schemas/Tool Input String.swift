// MARK: - Tool Input

extension String: ToolInput {
  public static var toolInputSchema: ToolInputStringSchema { ToolInputStringSchema() }
}

// MARK: - Schema

public struct ToolInputStringSchema: ToolInputSchema {

  public typealias DescribedValue = String

  public var description: String?
  public var minLength: Int?
  public var maxLength: Int?

  public init(
    description: String? = nil,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil
  ) {
    self.description = description
    self.minLength = minLength
    self.maxLength = maxLength
  }

  public func decodeValue(from decoder: ToolInputDecoder) throws -> String {
    try decoder.decoder.singleValueContainer().decode(String.self)
  }

  public func encode(_ value: DescribedValue, to encoder: ToolInputEncoder) throws {
    try value.encode(to: encoder.encoder)
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    enum CodingKey: Swift.CodingKey {
      case type, description, minLength, maxLength, pattern
    }
    var container = encoder.encoder.container(keyedBy: CodingKey.self)
    try container.encode("string", forKey: .type)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encodeIfPresent(minLength, forKey: .minLength)
    try container.encodeIfPresent(maxLength, forKey: .maxLength)
  }

  public var metadata: ToolInputSchemaMetadata<ToolInputStringSchema> {
    ToolInputSchemaMetadata(
      primitiveRepresentation: description == nil && minLength == nil && maxLength == nil
        ? "string" : nil
    )
  }

}

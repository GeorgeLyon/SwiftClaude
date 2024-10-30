// MARK: - Tool Input

extension Bool: ToolInput {
  public static var toolInputSchema: ToolInputBoolSchema { ToolInputBoolSchema() }
}

// MARK: - Schema

public struct ToolInputBoolSchema: ToolInputSchema {

  public typealias DescribedValue = Bool

  public var description: String?

  public init(description: String? = nil) {
    self.description = description
  }

  public func decodeValue(from decoder: ToolInputDecoder) throws -> Bool {
    try decoder.decoder.singleValueContainer().decode(Bool.self)
  }

  public func encode(_ value: Bool, to encoder: ToolInputEncoder) throws {
    var container = encoder.encoder.singleValueContainer()
    try container.encode(value)
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    enum CodingKey: Swift.CodingKey {
      case type, description
    }
    var container = encoder.encoder.container(keyedBy: CodingKey.self)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encode("boolean", forKey: .type)
  }

  public var metadata: ToolInputSchemaMetadata<ToolInputBoolSchema> {
    ToolInputSchemaMetadata(
      primitiveRepresentation: description == nil ? "boolean" : nil
    )
  }

}

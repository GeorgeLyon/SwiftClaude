// MARK: - Input

public protocol ToolInput {
  associatedtype ToolInputSchema: ClaudeToolInput.ToolInputSchema
  static var toolInputSchema: ToolInputSchema { get }
  init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) throws
  var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue { get }
}

extension ToolInput where ToolInputSchema.DescribedValue == Self {
  public init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) throws {
    self = toolInputSchemaDescribedValue
  }
  public var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
    return self
  }
}

// MARK: - Schema

public protocol ToolInputSchema {
  associatedtype DescribedValue: Sendable
  var metadata: ToolInputSchemaMetadata<Self> { get }
  func decodeValue(from decoder: ToolInputDecoder) throws -> DescribedValue

  /// Encodes a described value to an encoder
  /// Encoding is required so we can serialize `tool_use` content blocks and create synthetic tool invocations
  func encode(_ value: DescribedValue, to encoder: ToolInputEncoder) throws

  func encode(to encoder: ToolInputSchemaEncoder) throws
}

public struct ToolInputSchemaMetadata<Schema: ToolInputSchema> {
  /// Whether or not this schema accepts `null` as a valid value
  let acceptsNullValue: Bool

  /// A value which can be used to inidicate `null` values.
  /// This is used when a property key is missing during object decoding
  let nullValue: Schema.DescribedValue?

  /// Simple schemas which can be represented by a string (such as "boolean") should indicate this in their metadata by providing a non-`nil` `primitiveRepresentation`.
  let primitiveRepresentation: String?

  init(
    acceptsNullValue: Bool = false,
    nullValue: Schema.DescribedValue? = nil,
    primitiveRepresentation: String? = nil
  ) {
    self.acceptsNullValue = acceptsNullValue
    self.nullValue = nullValue
    self.primitiveRepresentation = primitiveRepresentation
  }
}
extension ToolInputSchema {
  public var metadata: ToolInputSchemaMetadata<Self> {
    ToolInputSchemaMetadata()
  }
}

public struct ToolInputSchemaEncoder {
  fileprivate init(encoder: Encoder) {
    self.encoder = encoder
  }
  let encoder: Encoder
}

public struct ToolInputEncoder {
  let encoder: Encoder
}

public struct ToolInputDecoder {
  let decoder: Decoder
}

// MARK: - Codable Containers

/// Package-private for now so we don't expose the encoding of `ToolInput` publicly.
/// We may also want to implement fancy stuff like schema references so this may change.
package struct ToolInputSchemaEncodingContainer<
  ToolInputSchema: ClaudeToolInput.ToolInputSchema
>: Encodable {
  package func encode(to encoder: any Encoder) throws {
    try schema.encode(to: ToolInputSchemaEncoder(encoder: encoder))
  }
  package init(schema: ToolInputSchema) {
    self.schema = schema
  }
  private let schema: ToolInputSchema
}

/// Package-private for now so we don't expose the encoding of `ToolInput` publicly
package struct ToolInputDecodableContainer<
  ToolInput: ClaudeToolInput.ToolInput
>: Decodable {
  public init(from decoder: Decoder) throws {
    let schema = ToolInput.toolInputSchema
    toolInput = try ToolInput(
      toolInputSchemaDescribedValue: schema.decodeValue(from: decoder)
    )
  }
  public let toolInput: ToolInput
}

/// Package-private for now so we don't expose the encoding of `ToolInput` publicly
package struct ToolInputEncodableContainer<
  ToolInput: ClaudeToolInput.ToolInput
>: Encodable, Sendable {
  public init(toolInput: ToolInput) {
    value = toolInput.toolInputSchemaDescribedValue
  }
  public func encode(to encoder: Encoder) throws {
    try ToolInput.toolInputSchema.encode(
      value,
      to: encoder
    )
  }
  private let value: ToolInput.ToolInputSchema.DescribedValue
}

// MARK: - Convenience

extension ToolInputSchema {
  func decodeValue(from decoder: Decoder) throws -> DescribedValue {
    try decodeValue(from: ToolInputDecoder(decoder: decoder))
  }
  func encode(_ value: DescribedValue, to encoder: Encoder) throws {
    try encode(value, to: ToolInputEncoder(encoder: encoder))
  }
  func encode(to encoder: Encoder) throws {
    try encode(to: ToolInputSchemaEncoder(encoder: encoder))
  }
}

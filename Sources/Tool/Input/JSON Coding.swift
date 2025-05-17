public import Foundation

extension JSONDecoder {

  public func decodeValue<Schema: ToolInput.Schema>(
    using schema: Schema,
    from data: Data
  ) throws -> Schema.Value {
    try $schemaValueDecodingContainerSchema.withValue(schema as any ToolInput.Schema) {
      try decode(SchemaValueDecodingContainer<Schema>.self, from: data).value
    }
  }

}

extension JSONEncoder {

  func encode<Schema: ToolInput.Schema>(
    _ value: Schema.Value,
    using schema: Schema
  ) throws -> Data {
    try encode(SchemaValueEncodingContainer(schema: schema, value: value))
  }

  func encode<Schema: ToolInput.Schema>(
    _ schema: Schema
  ) throws -> Data {
    try encode(
      SchemaEncodingContainer(schema: schema)
    )
  }

}

// MARK: - Implementation Details

// MARK: Value Decoding

private struct SchemaValueDecodingContainer<Schema: ToolInput.Schema>: Decodable {

  init(from decoder: Decoder) throws {
    guard let untypedSchema = schemaValueDecodingContainerSchema else {
      throw InvalidSchemaError(schema: nil)
    }
    guard let schema = untypedSchema as? Schema else {
      throw InvalidSchemaError(schema: untypedSchema)
    }
    value = try schema.decodeValue(
      from: ToolInput.Decoder(wrapped: decoder)
    )
  }

  let value: Schema.Value

}

/// We use `TaskLocal` instead of `CodingUserInfoKey` since it is a little simpler and safer to manage.
@TaskLocal
private var schemaValueDecodingContainerSchema: (any ToolInput.Schema)?

/// Shouldn't be thrown, indicates programmer error
private struct InvalidSchemaError: Error {
  let schema: Sendable?
}

// MARK: Value Encoding

private struct SchemaValueEncodingContainer<Schema: ToolInput.Schema>: Encodable {

  let schema: Schema
  let value: Schema.Value

  func encode(to encoder: Encoder) throws {
    try schema.encode(
      value,
      to: ToolInput.Encoder(wrapped: encoder)
    )
  }

}

// MARK: Schema Encoding

private struct SchemaEncodingContainer<Schema: ToolInput.Schema>: Encodable {

  let schema: Schema

  func encode(to encoder: Encoder) throws {
    try schema.encodeSchemaDefinition(
      to: ToolInput.SchemaEncoder(wrapped: encoder)
    )
  }

}

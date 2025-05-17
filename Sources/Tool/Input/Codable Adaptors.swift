extension ToolInput {

  public struct EncodableAdaptor<Schema: ToolInput.Schema>: Encodable {
    public init(
      schema: Schema,
      value: Schema.Value
    ) {
      self.schema = schema
      self.value = value
    }

    public func encode(to encoder: Swift.Encoder) throws {
      try schema.encode(value, to: Encoder(wrapped: encoder))
    }

    let schema: Schema
    let value: Schema.Value
  }

}

extension ToolInput.EncodableAdaptor: Sendable where Schema.Value: Sendable {}

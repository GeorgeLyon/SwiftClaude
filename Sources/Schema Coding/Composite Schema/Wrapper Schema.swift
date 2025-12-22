extension SchemaCoding.Schema {

  func wrap<NewValue>(
    _ wrap: @escaping @Sendable (Value) throws -> NewValue,
    unwrap: @escaping @Sendable (NewValue) -> Value
  ) -> SchemaCoding.Support.WrapperSchema<NewValue, Self> {
    SchemaCoding.Support.WrapperSchema(
      wrappedSchema: self,
      wrap: wrap,
      unwrap: unwrap
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  struct WrapperSchema<Value, WrappedSchema: Schema>: Schema {

    public func encode(_ value: Value, to encoder: inout Encoder) {
      wrappedSchema.encode(unwrap(value), to: &encoder)
    }

    func beginDecodingValue(from decoder: borrowing Decoder) -> WrappedSchema.ValueDecodingState {
      wrappedSchema.beginDecodingValue(from: decoder)
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try wrappedSchema
        .decodeValue(from: &decoder, state: &state)
        .map(wrap)
    }

    typealias MetaSchema = WrapperSchema<Self, WrappedSchema.MetaSchema>
    public func metaSchema(in context: SchemaContext) -> MetaSchema {
      wrappedSchema.metaSchema(in: context)
        .wrap { wrappedSchema in
          Self(
            wrappedSchema: wrappedSchema,
            wrap: wrap,
            unwrap: unwrap
          )
        } unwrap: { wrapperSchema in
          wrapperSchema.wrappedSchema
        }
    }

    fileprivate let wrappedSchema: WrappedSchema
    fileprivate let wrap: @Sendable (WrappedSchema.Value) throws -> Value
    fileprivate let unwrap: @Sendable (Value) -> WrappedSchema.Value

  }

}

// MARK: - Conformances

extension SchemaCoding.Support.WrapperSchema: SchemaCoding.Support.ObjectSchema
where WrappedSchema: SchemaCoding.Support.ObjectSchema {

  var properties:
    SchemaCoding.Support.WrapperObjectSchemaProperties<Value, WrappedSchema.Properties>
  {
    SchemaCoding.Support.WrapperObjectSchemaProperties(
      wrappedProperties: wrappedSchema.properties,
      wrap: { wrapped in
        try wrap(wrapped)
      },
      unwrap: { wrapper in
        unwrap(wrapper)
      }
    )
  }

  var objectSchemaMetadata: SchemaCoding.Support.ObjectSchemaMetadata {
    wrappedSchema.objectSchemaMetadata
  }

}

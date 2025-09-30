extension SchemaCoding.Schema {

  func wrap<NewValue: Sendable>(
    _ wrap: @escaping @Sendable (Value) throws -> NewValue,
    unwrap: @escaping @Sendable (NewValue) -> Value
  ) -> SchemaCoding.Support._WrapperSchema<NewValue, Self> {
    SchemaCoding.Support._WrapperSchema(
      wrappedSchema: self,
      wrap: wrap,
      unwrap: unwrap
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct _WrapperSchema<Value: Sendable, _WrappedSchema: Schema>: Schema {

    public typealias WrappedSchema = _WrappedSchema

    public func encode(_ value: Value, to encoder: inout Encoder) {
      wrappedSchema.encode(unwrap(value), to: &encoder)
    }

    public var initialValueDecodingState: WrappedSchema.ValueDecodingState {
      wrappedSchema.initialValueDecodingState
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try wrappedSchema
        .decodeValue(from: &decoder, state: &state)
        .map(wrap)
    }

    public var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
      wrappedSchema.schemaMetadata
    }

    #if ENABLE_META_SCHEMA
      public func metaSchema(in context: SchemaContext) -> some Schema<Self> {
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
    #endif

    fileprivate let wrappedSchema: WrappedSchema
    fileprivate let wrap: @Sendable (WrappedSchema.Value) throws -> Value
    fileprivate let unwrap: @Sendable (Value) -> WrappedSchema.Value

  }

}

// MARK: - ObjectSchema

extension SchemaCoding.Support._WrapperSchema: SchemaCoding.ObjectSchema
where WrappedSchema: SchemaCoding.ObjectSchema {

  public typealias PropertyStates = WrappedSchema.PropertyStates

  #if ENABLE_META_SCHEMA
    public var propertiesMetaSchema:
      SchemaCoding.Support._WrapperSchema<Self, WrappedSchema.PropertiesMetaSchema>
    {
      wrappedSchema.propertiesMetaSchema
        .wrap { wrapped in
          Self(
            wrappedSchema: wrapped,
            wrap: wrap,
            unwrap: unwrap
          )
        } unwrap: { wrapper in
          wrapper.wrappedSchema
        }
    }
  #endif

  public func encodeProperties(
    of value: Value,
    to encoder: inout SchemaCoding.Support.ObjectEncoder
  ) {
    wrappedSchema.encodeProperties(of: unwrap(value), to: &encoder)
  }

  public func finishDecoding(_ states: WrappedSchema.PropertyStates) throws -> Value {
    try wrap(wrappedSchema.finishDecoding(states))
  }

  public var objectSchemaMetadata: SchemaCoding.Support.ObjectSchemaMetadata {
    wrappedSchema.objectSchemaMetadata
  }

}

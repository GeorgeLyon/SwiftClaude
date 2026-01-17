extension SchemaCoding.Support {

  struct ConstantSchema<
    WrappedSchema: SchemaCoding.Schema
  >: Schema where WrappedSchema.Value: Equatable {

    public typealias Value = Void

    public func encode(
      _ value: Value,
      to encoder: inout Encoder
    ) {
      encoder.stream.encode(constantValue, using: wrappedSchema)
    }

    public typealias ValueDecodingState = WrappedSchema.ValueDecodingState

    public func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      wrappedSchema.beginDecodingValue(from: decoder)
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout WrappedSchema.ValueDecodingState
    ) throws -> DecodingResult<Value> {
      switch try wrappedSchema.decodeValue(from: &decoder, state: &state).kind {
      case .incomplete:
        return .incomplete
      case .decoded(let value):
        guard value == constantValue else {
          throw Error.constantValueMismatch
        }
        return .decoded(())
      }
    }

    // typealias MetaSchema = WrapperSchema<
    //   Self,
    //   ConcreteObjectSchema<
    //     TupleObjectSchemaProperties<
    //       OptionalObjectProperty<StringSchema>,
    //       DirectObjectProperty<Self>
    //     >
    //   >
    // >
    // public var metaSchema: MetaSchema {
    //   let objectSchema = ConcreteObjectSchema {
    //     OptionalObjectProperty(
    //       name: .description,
    //       schema: OptionalSchema(wrappedSchema: StringSchema())
    //     )
    //     DirectObjectProperty(
    //       name: .const,
    //       schema: self
    //     )
    //   }
    //   return objectSchema.wrap { (description, _) in
    //     Self(
    //       description: description,
    //       wrappedSchema: wrappedSchema,
    //       constantValue: constantValue
    //     )
    //   } unwrap: { schema in
    //     (schema.description, ())
    //   }
    // }

    init(
      description: String? = nil,
      wrappedSchema: WrappedSchema,
      constantValue: WrappedSchema.Value
    ) {
      self.metadata = SchemaMetadata(description: description)
      self.wrappedSchema = wrappedSchema
      self.constantValue = constantValue
    }

    var metadata: SchemaMetadata
    let wrappedSchema: WrappedSchema
    let constantValue: WrappedSchema.Value

  }

  private enum Error: Swift.Error {
    case constantValueMismatch
  }

}

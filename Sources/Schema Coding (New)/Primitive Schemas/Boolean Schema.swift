import JSONSupport

extension Bool: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support.BooleanSchema {
    SchemaCoding.Support.BooleanSchema(description: nil)
  }

}

extension SchemaCoding.Support {

  public struct BooleanSchema: Schema {

    public typealias Value = Bool

    public func encode(_ value: Bool, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    public typealias ValueDecodingState = Void

    public func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ()
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Bool> {
      try decoder.stream.decodeBoolean()
        .schemaDecodingResult
    }

    // public struct MetaSchema {

    // }
    // public var metaSchema: MetaSchema {
    //   let objectSchema = ConcreteObjectSchema {
    //     OptionalObjectProperty(
    //       name: .description,
    //       schema: OptionalSchema(wrappedSchema: StringSchema())
    //     )
    //     DirectObjectProperty(
    //       name: .type,
    //       schema: ConstantSchema(
    //         wrappedSchema: StringSchema(),
    //         constantValue: "boolean"
    //       )
    //     )
    //   }
    //   return objectSchema.wrap { (description, _) in
    //     Self(description: description)
    //   } unwrap: { schema in
    //     (schema.description, ())
    //   }
    // }

    public init(description: String? = nil) {
      self.metadata = SchemaMetadata(description: description)
    }
    public var metadata: SchemaMetadata

  }

}

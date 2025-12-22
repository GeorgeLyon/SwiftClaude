import JSONSupport

extension Int: SchemaCoding.SchemaCodable {}
extension Int8: SchemaCoding.SchemaCodable {}
extension Int16: SchemaCoding.SchemaCodable {}
extension Int32: SchemaCoding.SchemaCodable {}
extension Int64: SchemaCoding.SchemaCodable {}
extension Int128: SchemaCoding.SchemaCodable {}
extension UInt: SchemaCoding.SchemaCodable {}
extension UInt8: SchemaCoding.SchemaCodable {}
extension UInt16: SchemaCoding.SchemaCodable {}
extension UInt32: SchemaCoding.SchemaCodable {}
extension UInt64: SchemaCoding.SchemaCodable {}
extension UInt128: SchemaCoding.SchemaCodable {}

extension SchemaCoding.Support {

  public static func schema<T: FixedWidthInteger & SendableMetatype>(
    representing: T.Type = T.self,
    description: String? = nil
  ) -> some Schema<T> {
    IntegerSchema(description: description)
  }

}

extension FixedWidthInteger where Self: SendableMetatype {

  public static var schema: some SchemaCoding.Schema<Self> {
    SchemaCoding.Support.schema(
      representing: Self.self
    )
  }

}

extension SchemaCoding.Support {

  struct IntegerSchema<T: FixedWidthInteger & SendableMetatype>: Schema {

    typealias Value = T

    func encode(_ value: T, to encoder: inout Encoder) {
      encoder.stream.encode(value)
    }

    typealias ValueDecodingState = Void

    func beginDecodingValue(
      from decoder: borrowing Decoder
    ) -> ValueDecodingState {
      ()
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<T> {
      try decoder.stream.decodeNumber()
        .map { try $0.decode(as: T.self) }
        .schemaDecodingResult
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<String.Schema>,
          RequiredObjectProperty<ConstantSchema<String.Schema>>
        >
      >
    >
    func metaSchema(in context: SchemaContext) -> MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: String.schema
        )
        RequiredObjectProperty(
          name: .type,
          schema: ConstantSchema(
            wrappedSchema: String.schema,
            constantValue: type
          )
        )
      }
      return objectSchema.wrap { (description, _) in
        Self(description: description)
      } unwrap: { schema in
        (schema.description, ())
      }
    }

    let description: String?
    let type = "integer"

  }

}

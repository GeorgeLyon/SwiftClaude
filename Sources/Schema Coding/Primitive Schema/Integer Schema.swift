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

  fileprivate struct IntegerSchema<T: FixedWidthInteger & SendableMetatype>: Schema {

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

    func metaSchema(in context: SchemaContext) -> some Schema<Self> {
      let objectSchema = objectSchema(
        description: nil,
        propertyName: SchemaPropertyName.self,
        properties: {
          objectProperty(
            name: SchemaPropertyName.description,
            schema: String?.schema
          )
          objectProperty(
            name: SchemaPropertyName.type,
            schema: schema(constantValue: type)
          )
        }
      )
      let wrapperSchema =
        objectSchema
        .wrap { (description, _) in
          Self(description: description)
        } unwrap: { schema in
          (schema.description, ())
        }
      return wrapperSchema
    }

    let description: String?
    let type = "integer"

  }

}

private enum SchemaPropertyName: CodingKey {
  case description, type
}

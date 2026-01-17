extension SchemaCoding.Support {

  public protocol XSchema {
    associatedtype Value
    func encode(_ value: Value, to encoder: inout Encoder)
  }

  public protocol EnumSchemaProtocol: XSchema {
    associatedtype Style: EnumSchemaStyle = EnumSchemaStyleStandard
    static var style: Style { get }

    associatedtype Cases
    static var cases: Cases { get }

    associatedtype ValueEncoder: ~Copyable
    static func encodeValue(_ value: Value, to encoder: inout ValueEncoder)

  }

  public protocol EnumSchemaStyle: Style {

  }

}

extension SchemaCoding.Support.EnumSchemaProtocol
where Style == SchemaCoding.Support.EnumSchemaStyleStandard {

  public static var style: Style { .standard }

  public func encode<each AssociatedValuesSchema>(
    _ value: Value,
    to encoder: inout SchemaCoding.Support.Encoder
  )
  where
    ValueEncoder == SchemaCoding.Support.EnumSchemaEncoder<repeat each AssociatedValuesSchema>,
    Cases == SchemaCoding.Support.EnumSchemaCases<Value, repeat each AssociatedValuesSchema>
  {
    let cases = Self.cases.cases
    var valueEncoder = ValueEncoder(
      encodings: (repeat SchemaCoding.Support.EnumSchemaCaseEncoding(
        name: (each cases).name.stringValue,
        schema: (each cases).associatedValuesSchema
      )),
      valueEncoder: encoder
    )
    Self.encodeValue(value, to: &valueEncoder)
    assert(valueEncoder.isEncoded)
    encoder = valueEncoder.valueEncoder
  }

}

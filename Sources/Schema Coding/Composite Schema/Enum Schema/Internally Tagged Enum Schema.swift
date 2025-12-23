/*
extension SchemaCoding.Support {

  struct InternallyTaggedEnumSchema<
    Value,
    DisambiguatorSchema: Schema,
    each AssociatedValuesSchema: ObjectSchema
  >: Schema where DisambiguatorSchema.Value: Hashable {

    func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
      var enumEncoder = EnumSchemaEncoder(
        encodings: (repeat EnumSchemaCaseEncoding(
          name: (each cases).name.stringValue,
          schema: (each cases).associatedValuesSchema
        )),
        valueEncoder: encoder
      )
      encodeValue(value, &enumEncoder)
      assert(enumEncoder.isEncoded)
      encoder = enumEncoder.valueEncoder
    }

    let cases: (repeat EnumSchemaCase<Value, InternallyTaggedSchema<DisambiguatorSchema, each AssociatedValuesSchema>>)
  }

  typealias InternallyTaggedSchema<
    DisambiguatorSchema: Schema,
    WrappedSchema: ObjectSchema
  > = ConcreteObjectSchema<
      CompositeObjectSchemaProperties<
        WrappedSchema.Properties,
        TupleObjectSchemaProperties<
          RequiredObjectProperty<
            ConstantSchema<
              DisambiguatorSchema
            >
          >
        >
      >
    > where DisambiguatorSchema.Value: Equatable

  }

}

// MARK: - Encoding

*/

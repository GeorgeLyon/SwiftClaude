import JSONSupport

extension SchemaCoding.Support {

  public static func schema<Value: CaseIterable & RawRepresentable & SendableMetatype>(
    representing _: Value.Type = Value.self,
    description: String?
  ) -> some SchemaCoding.Schema<Value>
  where Value.RawValue == String {
    CaseIterableStringEnumSchema(
      description: description
    )
  }

  public static func schema<Value: CaseIterable & RawRepresentable & SendableMetatype>(
    representing _: Value.Type = Value.self,
    description: String?
  ) -> some SchemaCoding.Schema<Value>
  where Value.RawValue: FixedWidthInteger & Sendable {
    CaseIterableIntEnumSchema(
      description: description
    )
  }

}

/// If something is `SchemaCodable`, we want to use its defined schema because it may include an additional description which the `CaseIterable` variants above don't capture.
extension SchemaCoding.Support {

  public static func schema<Value: SchemaCodable & CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self
  ) -> some SchemaCoding.Schema<Value>
  where Value.RawValue == String {
    Value.schema
  }

  public static func schema<Value: SchemaCodable & CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self
  ) -> some SchemaCoding.Schema<Value>
  where Value.RawValue: FixedWidthInteger {
    Value.schema
  }

}

// MARK: - Implementation Details

extension SchemaCoding.Support {

  private struct CaseIterableStringEnumSchema<
    Value: CaseIterable & RawRepresentable & SendableMetatype
  >: Schema
  where Value.RawValue == String {

    func encode(_ value: Value, to encoder: inout Encoder) {
      wrappedSchema.encode(value.rawValue, to: &encoder)
    }

    typealias ValueDecodingState = WrappedSchema.ValueDecodingState

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      wrappedSchema.beginDecodingValue(from: decoder)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try wrappedSchema
        .decodeValue(from: &decoder, state: &state)
        .map { rawValue in
          guard let value = Value(rawValue: rawValue) else {
            throw Error.unknownEnumCase("\(rawValue)")
          }
          return value
        }
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          RequiredObjectProperty<ConstantSchema<ArraySchema<WrappedSchema>>>
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: StringSchema()
        )
        RequiredObjectProperty(
          name: .enum,
          schema: ConstantSchema(
            wrappedSchema: ArraySchema(elementSchema: wrappedSchema),
            constantValue: Array(Value.allCases.map(\.rawValue))
          )
        )
      }
      return objectSchema.wrap { (description, _) in
        Self(description: description)
      } unwrap: { schema in
        (description, ())
      }
    }

    typealias WrappedSchema = StringSchema
    init(description: String?) {
      wrappedSchema = WrappedSchema(description: description)
    }
    var metadata: SchemaMetadata {
      get { wrappedSchema.metadata }
      set { wrappedSchema.metadata = newValue }
    }
    var wrappedSchema: WrappedSchema
  }

  private struct CaseIterableIntEnumSchema<
    Value: CaseIterable & RawRepresentable & SendableMetatype
  >: Schema
  where Value.RawValue: FixedWidthInteger & Sendable {

    func encode(_ value: Value, to encoder: inout Encoder) {
      wrappedSchema.encode(value.rawValue, to: &encoder)
    }

    typealias ValueDecodingState = WrappedSchema.ValueDecodingState

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      wrappedSchema.beginDecodingValue(from: decoder)
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try wrappedSchema
        .decodeValue(from: &decoder, state: &state)
        .map { rawValue in
          guard let value = Value(rawValue: rawValue) else {
            throw Error.unknownEnumCase("\(rawValue)")
          }
          return value
        }
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ConcreteObjectSchema<
        TupleObjectSchemaProperties<
          OptionalObjectProperty<StringSchema>,
          RequiredObjectProperty<ConstantSchema<ArraySchema<WrappedSchema>>>
        >
      >
    >
    var metaSchema: MetaSchema {
      let objectSchema = ConcreteObjectSchema {
        OptionalObjectProperty(
          name: .description,
          schema: StringSchema()
        )
        RequiredObjectProperty(
          name: .enum,
          schema: ConstantSchema(
            wrappedSchema: ArraySchema(elementSchema: wrappedSchema),
            constantValue: Array(Value.allCases.map(\.rawValue))
          )
        )
      }
      return objectSchema.wrap { (description, _) in
        Self(description: description)
      } unwrap: { schema in
        (description, ())
      }
    }

    typealias WrappedSchema = IntegerSchema<Value.RawValue>
    init(description: String?) {
      wrappedSchema = WrappedSchema(description: description)
    }
    var metadata: SchemaMetadata {
      get { wrappedSchema.metadata }
      set { wrappedSchema.metadata = newValue }
    }
    var wrappedSchema: WrappedSchema
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownEnumCase(String)
}

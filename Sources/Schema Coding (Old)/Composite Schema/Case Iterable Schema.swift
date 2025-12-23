import JSONSupport

extension SchemaCoding.Support {

  public static func schema<Value: CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self,
    description: String?
  ) -> some SchemaCoding.Schema<Value>
  where Value.RawValue == String {
    CaseIterableStringEnumSchema(
      description: description,
      wrappedSchema: schema(
        representing: Value.RawValue.self
      )
    )
  }

  public static func schema<Value: CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self,
    description: String?
  ) -> some SchemaCoding.Schema<Value>
  where Value.RawValue: FixedWidthInteger {
    CaseIterableIntEnumSchema(
      description: description,
      wrappedSchema: schema(
        representing: Value.RawValue.self
      )
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

  fileprivate protocol CaseIterableEnumSchema: Schema
  where
    Value: CaseIterable & RawRepresentable
  {
    init(description: String?, wrappedSchema: WrappedSchema)

    associatedtype WrappedSchema: Schema
    where
      WrappedSchema.Value: Equatable,
      WrappedSchema.Value == Value.RawValue,
      WrappedSchema.ValueDecodingState == ValueDecodingState
    var description: String? { get }
    var wrappedSchema: WrappedSchema { get }
  }

  private struct CaseIterableStringEnumSchema<
    Value: CaseIterable & RawRepresentable,
    WrappedSchema: SchemaCoding.Schema<String>
  >:
    CaseIterableEnumSchema
  where Value.RawValue == String {
    typealias ValueDecodingState = WrappedSchema.ValueDecodingState
    let description: String?
    let wrappedSchema: WrappedSchema
  }

  private struct CaseIterableIntEnumSchema<
    Value: CaseIterable & RawRepresentable,
    WrappedSchema: SchemaCoding.Schema<Value.RawValue>
  >:
    CaseIterableEnumSchema
  where Value.RawValue: FixedWidthInteger {
    typealias ValueDecodingState = WrappedSchema.ValueDecodingState
    let description: String?
    let wrappedSchema: WrappedSchema
  }

}

extension SchemaCoding.Support.CaseIterableEnumSchema {

  func encode(
    _ value: Value,
    to encoder: inout SchemaCoding.Support.Encoder
  ) {
    wrappedSchema.encode(value.rawValue, to: &encoder)
  }

  func decodeValue(
    from decoder: inout SchemaCoding.Support.Decoder,
    state: inout ValueDecodingState
  ) throws -> SchemaCoding.Support.DecodingResult<Value> {
    try wrappedSchema
      .decodeValue(from: &decoder, state: &state)
      .map { rawValue in
        guard let value = Value(rawValue: rawValue) else {
          throw Error.unknownEnumCase("\(rawValue)")
        }
        return value
      }
  }

  var initialValueDecodingState: ValueDecodingState {
    wrappedSchema.initialValueDecodingState
  }

  var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
    wrappedSchema.schemaMetadata
  }

  func metaSchema(
    in context: SchemaCoding.Support.SchemaContext
  ) -> some SchemaCoding.Schema<Self> {
    let schema = SchemaCoding.Support.objectSchema {
      SchemaCoding.Support.objectProperty(
        name: SchemaCodingKey.description,
        constantValue: context.contextualDescription(for: description)
      )
      SchemaCoding.Support.objectProperty(
        name: SchemaCodingKey.enum,
        schema: SchemaCoding.Support._ConstantSchema(
          wrappedSchema: SchemaCoding.Support._ArraySchema(
            description: nil,
            elementSchema: wrappedSchema
          ),
          constantValue: Array(Value.allCases.map(\.rawValue)))
      )
    }
    return schema.wrap { (wrapped: (()?, ())) -> Self in
      Self(description: description, wrappedSchema: wrappedSchema)
    } unwrap: { (wrapper: Self) -> (()?, ()) in
      ((), ())
    }
  }

}

// MARK: - Coding Keys

private enum SchemaCodingKey: CodingKey {
  case description, `enum`
}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownEnumCase(String)
}

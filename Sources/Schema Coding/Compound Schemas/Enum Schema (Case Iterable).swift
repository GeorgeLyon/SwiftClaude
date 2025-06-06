import JSONSupport

/// It is also possible to conform a `CaseIterable` enum to `SchemaCodable` directly and use the `CaseIterable`-based schema.
extension SchemaSupport {

  public static func enumSchema<Value: CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self,
    description: String? = nil
  ) -> some Schema<Value>
  where Value.RawValue == String {
    CaseIterableStringEnumSchema(description: description)
  }

  public static func enumSchema<Value: CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self,
    description: String? = nil
  ) -> some Schema<Value>
  where Value.RawValue: FixedWidthInteger & Codable & Sendable {
    CaseIterableIntegerEnumSchema(description: description)
  }
  public static func enumSchema<
    Value: CaseIterable & RawRepresentable,
    each AssociatedValuesSchema: Schema
  >(
    representing _: Value.Type,
    description: String?,
    cases: (
      repeat (
        key: SchemaSupport.SchemaCodingKey,
        description: String?,
        associatedValuesSchema: each AssociatedValuesSchema,
        initializer: @Sendable ((each AssociatedValuesSchema).Value) -> Value
      )
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValuesSchema).Value) -> EnumCaseEncoder
    ) -> EnumCaseEncoder
  ) -> some Schema<Value>
  where Value.RawValue == String {
    /// Fall back to case iterable conformance if an enum is case iterable
    return CaseIterableStringEnumSchema(description: description)
  }

  /// Overload that is in the same shape as the standard enum schema, but simplifies it to a case iterable schema if the type conforms
  @_disfavoredOverload
  public static func enumSchema<
    Value: CaseIterable & RawRepresentable,
    each AssociatedValuesSchema: Schema
  >(
    representing _: Value.Type,
    description: String?,
    cases: (
      repeat (
        key: SchemaSupport.SchemaCodingKey,
        description: String?,
        associatedValuesSchema: each AssociatedValuesSchema,
        initializer: @Sendable ((each AssociatedValuesSchema).Value) -> Value
      )
    ),
    caseEncoder: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValuesSchema).Value) -> EnumCaseEncoder
    ) -> EnumCaseEncoder
  ) -> some Schema<Value>
  where Value.RawValue: FixedWidthInteger & Codable & Sendable {
    /// Fall back to case iterable conformance if an enum is case iterable
    return CaseIterableIntegerEnumSchema(description: description)
  }

}

// MARK: - Implementation Details

private protocol CaseIterableEnumSchema: InternalSchema
where
  Value: CaseIterable & RawRepresentable,
  Value.RawValue: Codable & Sendable
{
  var description: String? { get }
  static func encode(_ value: Value, to stream: inout JSON.EncodingStream)
  static func decodeRawValue(from stream: inout JSON.DecodingStream) throws
    -> JSON.DecodingResult<Value.RawValue>
}

extension CaseIterableEnumSchema {

  func encodeSchemaDefinition(to encoder: inout SchemaSupport.SchemaEncoder) {
    let description = encoder.contextualDescription(description)
    encoder.stream.encodeObject { stream in
      if let description {
        stream.encodeProperty(name: "description") { $0.encode(description) }
      }
      stream.encodeProperty(name: "enum") { stream in
        stream.encodeArray { array in
          for value in Value.allCases {
            array.encodeElement { Self.encode(value, to: &$0) }
          }
        }
      }
    }
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ()
  ) throws -> JSON.DecodingResult<Value> {
    try Self.decodeRawValue(from: &stream)
      .map { rawValue in
        guard let value = Value(rawValue: rawValue) else {
          throw Error.unknownEnumCase(allKeys: ["\(rawValue)"])
        }
        return value
      }
  }

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    Self.encode(value, to: &stream)
  }

}

private struct CaseIterableStringEnumSchema<Value: CaseIterable & RawRepresentable>:
  CaseIterableEnumSchema
where Value.RawValue == String {
  let description: String?
  static func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    stream.encode(value.rawValue)
  }
  static func decodeRawValue(from stream: inout JSON.DecodingStream) throws
    -> JSON.DecodingResult<Value.RawValue>
  {
    try stream.decodeString().map(String.init)
  }
}

private struct CaseIterableIntegerEnumSchema<Value: CaseIterable & RawRepresentable>:
  CaseIterableEnumSchema
where Value.RawValue: FixedWidthInteger & Codable & Sendable {
  let description: String?
  static func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    stream.encode(value.rawValue)
  }
  static func decodeRawValue(from stream: inout JSON.DecodingStream) throws
    -> JSON.DecodingResult<Value.RawValue>
  {
    try stream.decodeNumber().map { try $0.decode() }
  }
}

private enum Error: Swift.Error {
  case unknownEnumCase(allKeys: [String])
}

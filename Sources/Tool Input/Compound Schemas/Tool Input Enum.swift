// MARK: - Tool Input

/// `enum`s do not directly conform to `ToolInput`, but can be made to conform using the `@ToolInput` macro.

// MARK: - Schema

public struct ToolInputEnumSchema<
  each Case: ToolInputSchema
>: ToolInputSchema {
  public typealias DescribedValue = (repeat (each Case).DescribedValue?)

  public var description: String?
  public var cases: (repeat each Case)

  public init(
    description: String? = nil,
    _ cases: repeat (key: ToolInputSchemaKey, schema: each Case)
  ) {
    self.description = description

    ToolInputSchemaKey.assertAllKeysUniqueIn((repeat (each cases, (each cases).key)))
    self.cases = (repeat (each cases).schema)
    self.caseMetadata =
      (repeat (
        key: (each cases).key.codingKey,
        type: (each Case).self
      ))
  }

  public func decodeValue(from decoder: ToolInputDecoder) throws -> DescribedValue {
    let container = try decoder.decoder.container(keyedBy: ToolInputSchemaKey.CodingKey.self)
    var valuesDecoded = 0
    func decodeValueIfPresent<Schema: ToolInputSchema>(
      of schema: Schema,
      forKey key: ToolInputSchemaKey.CodingKey
    ) throws -> Schema.DescribedValue? {
      guard container.contains(key) else {
        return nil
      }
      valuesDecoded += 1
      return try schema.decodeValue(from: container.superDecoder(forKey: key))
    }
    let value = try (repeat decodeValueIfPresent(of: each cases, forKey: (each caseMetadata).key))
    guard valuesDecoded == 1 else {
      throw UnexpectedResidentValueCount(count: valuesDecoded)
    }
    return value
  }

  public func encode(_ value: DescribedValue, to encoder: ToolInputEncoder) throws {
    var container = encoder.encoder.container(keyedBy: ToolInputSchemaKey.CodingKey.self)
    var valuesEncoded = 0
    func encodeValueIfPresent<Schema: ToolInputSchema>(
      _ value: Schema.DescribedValue?,
      of schema: Schema,
      forKey key: ToolInputSchemaKey.CodingKey
    ) throws {
      guard let value = value else {
        return
      }
      valuesEncoded += 1
      try schema.encode(value, to: container.superEncoder(forKey: key))
    }
    repeat try encodeValueIfPresent(each value, of: each cases, forKey: (each caseMetadata).key)
    guard valuesEncoded == 1 else {
      throw UnexpectedResidentValueCount(count: valuesEncoded)
    }
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: ContainerCodingKey.self)
    try container.encode("object", forKey: .type)
    try container.encodeIfPresent(description, forKey: .description)

    do {
      var container = container.nestedContainer(
        keyedBy: ToolInputSchemaKey.CodingKey.self,
        forKey: .properties
      )
      for (schema, metadata) in repeat (each cases, each caseMetadata) {
        let encoder = container.superEncoder(forKey: metadata.key)
        try schema.encode(to: encoder)
      }
    }

    /// Only one property can be specified
    try container.encode(false, forKey: .additionalProperties)
    try container.encode(1, forKey: .minProperties)
    try container.encode(1, forKey: .maxProperties)

  }

  private let caseMetadata:
    (
      repeat (
        key: ToolInputSchemaKey.CodingKey,
        type: (each Case).Type
      )
    )
}

// MARK: - Error

/// An error `enum` types can use in a switch statement decoding the `DescribedValue` in the case that all cases are `.none`
/// This should never happen, but is not enforced by the type system.
public struct ToolInputEnumNoCaseSpecified: Error {
  public init() {
    assertionFailure()
  }
}

// MARK: - Implementation Details

private enum ContainerCodingKey: Swift.CodingKey {
  case type
  case description
  case properties
  case additionalProperties
  case maxProperties
  case minProperties
}

private struct UnspecifiedCase: Error {
  let keys: [CodingKey]?
}

private struct UnexpectedResidentValueCount: Error {
  let count: Int
}

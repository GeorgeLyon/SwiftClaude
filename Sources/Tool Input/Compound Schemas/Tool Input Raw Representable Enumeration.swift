// MARK: - Tool Input

extension ToolInput
where
  Self: CaseIterable & RawRepresentable,
  RawValue: ToolInput,
  RawValue.ToolInputSchema.DescribedValue == RawValue
{
  public static var toolInputSchema:
    ToolInputRawRepresentableEnumerationSchema<RawValue.ToolInputSchema>
  {
    let rawValues = allCases.map(\.rawValue)
    return ToolInputRawRepresentableEnumerationSchema(
      rawValue: RawValue.toolInputSchema,
      allCases: rawValues
    )
  }

  public init(toolInputSchemaDescribedValue: RawValue) throws {
    guard let value = Self(rawValue: toolInputSchemaDescribedValue) else {
      throw InvalidRawValue()
    }
    self = value
  }
  public var toolInputSchemaDescribedValue: RawValue { rawValue }
}

// MARK: - Schema

public struct ToolInputRawRepresentableEnumerationSchema<
  RawValue: ToolInputSchema
>: ToolInputSchema {
  public typealias DescribedValue = RawValue.DescribedValue
  public var description: String?
  public let rawValue: RawValue

  public init(
    description: String? = nil,
    rawValue: RawValue,
    allCases: some Sequence<RawValue.DescribedValue>
  ) {
    self.description = description
    self.rawValue = rawValue
    self.allCases = Array(allCases)
  }

  public func decodeValue(from decoder: ToolInputDecoder) throws -> DescribedValue {
    try rawValue.decodeValue(from: decoder)
  }

  public func encode(_ value: DescribedValue, to encoder: ToolInputEncoder) throws {
    try rawValue.encode(value, to: encoder)
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: CodingKey.self)
    if let description = description {
      try container.encode(description, forKey: .description)
    }
    var caseContainer = container.nestedUnkeyedContainer(forKey: .enum)
    for `case` in allCases {
      try rawValue.encode(`case`, to: caseContainer.superEncoder())
    }
  }

  private let allCases: [DescribedValue]
}

private enum CodingKey: String, Swift.CodingKey {
  case description
  case `enum`
}

private struct InvalidRawValue: Error {
}

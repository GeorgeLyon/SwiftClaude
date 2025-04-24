// MARK: - Defining Schemas

/// This extension defines a family of `enumSchema` methods.
/// These are intended to be added to enums via a macro and so are structured to be very regular.
extension ToolInput {

  @_disfavoredOverload
  public static func enumSchema<
    Value: CaseIterable & RawRepresentable,
    CaseKey: CodingKey,
    each AssociatedValueSchema: ToolInput.Schema
  >(
    representing _: Value.Type,
    description: String?,
    keyedBy _: CaseKey.Type,
    cases: (
      repeat (
        key: CaseKey,
        description: String?,
        associatedValueSchema: each AssociatedValueSchema,
        initializer: @Sendable ((each AssociatedValueSchema).Value) -> Value
      )
    ),
    encodeValue: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValueSchema).Value) throws -> Void
    ) throws -> Void
  ) -> some Schema<Value>
  where Value.RawValue == String {
    /// Fall back to case iterable conformance if an enum is case iterable
    return CaseIterableEnumSchema(description: description)
  }

  @_disfavoredOverload
  public static func enumSchema<
    Value: CaseIterable & RawRepresentable,
    CaseKey: CodingKey,
    each AssociatedValueSchema: ToolInput.Schema
  >(
    representing _: Value.Type,
    description: String?,
    keyedBy _: CaseKey.Type,
    cases: (
      repeat (
        key: CaseKey,
        description: String?,
        associatedValueSchema: each AssociatedValueSchema,
        initializer: @Sendable ((each AssociatedValueSchema).Value) -> Value
      )
    ),
    encodeValue: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValueSchema).Value) throws -> Void
    ) throws -> Void
  ) -> some Schema<Value>
  where Value.RawValue: BinaryInteger & Codable & Sendable {
    /// Fall back to case iterable conformance if an enum is case iterable
    return CaseIterableEnumSchema(description: description)
  }

  @_disfavoredOverload
  public static func enumSchema<
    Value,
    CaseKey: CodingKey,
    each AssociatedValueSchema: ToolInput.Schema
  >(
    representing _: Value.Type,
    description: String?,
    keyedBy _: CaseKey.Type,
    cases: (
      repeat (
        key: CaseKey,
        description: String?,
        associatedValueSchema: each AssociatedValueSchema,
        initializer: @Sendable ((each AssociatedValueSchema).Value) -> Value
      )
    ),
    encodeValue: @escaping @Sendable (
      Value,
      repeat ((each AssociatedValueSchema).Value) throws -> Void
    ) throws -> Void
  ) -> some Schema<Value> {
    StandardEnumSchema(
      description: description,
      cases: (repeat EnumSchemaCase(
        key: (each cases).key,
        description: (each cases).description,
        schema: (each cases).associatedValueSchema,
        initializer: (each cases).initializer
      )),
      encodeValue: encodeValue
    )
  }

}

/// It is also possible to conform a `CaseIterable` enum to `SchemaCodable` directly and use the `CaseIterable`-based schema.
extension ToolInput {

  public static func enumSchema<Value: CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self,
    description: String? = nil
  ) -> some Schema<Value>
  where Value.RawValue == String {
    CaseIterableEnumSchema(description: description)
  }

  public static func enumSchema<Value: CaseIterable & RawRepresentable>(
    representing _: Value.Type = Value.self,
    description: String? = nil
  ) -> some Schema<Value>
  where Value.RawValue: BinaryInteger & Codable & Sendable {
    CaseIterableEnumSchema(description: description)
  }

}

// MARK: - Defining Associated Values

extension ToolInput {

  public static func enumCaseAssociatedValuesSchema<
    Key: CodingKey
  >(
    keyedBy: Key.Type,
    values: ()
  ) -> some Schema<Void> {
    EnumCaseVoidAssociatedValueSchema()
  }

  public static func enumCaseAssociatedValuesSchema<
    Key: CodingKey,
    ValueSchema: Schema
  >(
    keyedBy: Key.Type,
    values: (
      key: Key?,
      schema: ValueSchema
    )
  ) -> some Schema<ValueSchema.Value> {
    values.schema
  }

  @_disfavoredOverload
  public static func enumCaseAssociatedValuesSchema<
    Key: CodingKey,
    each ValueSchema: Schema
  >(
    keyedBy: Key.Type,
    values: (
      repeat (
        key: Key,
        schema: each ValueSchema
      )
    )
  ) -> some Schema<(repeat (each ValueSchema).Value)> {
    /// Associated values which all have names are represented as an object
    ObjectPropertiesSchema(
      description: nil,
      properties: repeat ObjectPropertySchema(
        key: (each values).key,
        description: nil,
        schema: (each values).schema
      )
    )
  }

  @_disfavoredOverload
  public static func enumCaseAssociatedValuesSchema<
    Key: CodingKey,
    each ValueSchema: Schema
  >(
    keyedBy: Key.Type,
    values: (
      repeat (
        key: Key?,
        schema: each ValueSchema
      )
    )
  ) -> some Schema<(repeat (each ValueSchema).Value)> {
    TupleSchema(
      elements: (repeat (
        name: (each values).key?.stringValue,
        schema: (each values).schema
      ))
    )
  }

}

extension ToolInput {

  /// In the full enum schema, cases without associated values are represented using a `null` value.
  /// For example `{"myEnumCase":null}`
  private struct EnumCaseVoidAssociatedValueSchema: LeafSchema {

    typealias Value = Void

    let type: String = "null"

    func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
      var container = encoder.wrapped.singleValueContainer()
      try container.encodeNil()
    }

    func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
      guard try decoder.wrapped.singleValueContainer().decodeNil() else {
        struct ExpectedNil: Error {}
        throw ExpectedNil()
      }
      return ()
    }

  }

}

// MARK: - Schemas

// MARK: Case Iterable

private struct CaseIterableEnumSchema<Value: CaseIterable & RawRepresentable>: InternalSchema
where Value.RawValue: Codable & Sendable {

  let description: String?

  func encodeSchemaDefinition(to encoder: ToolInput.SchemaEncoder<Self>) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)

    if let description = encoder.contextualDescription(description) {
      try container.encode(description, forKey: .description)
    }

    try container.encode(Value.allCases.map(\.rawValue), forKey: .enum)
  }

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    var container = encoder.wrapped.singleValueContainer()
    try container.encode(value.rawValue)
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    let rawValue = try decoder.wrapped.singleValueContainer()
      .decode(Value.RawValue.self)
    guard let value = Value(rawValue: rawValue) else {
      throw EnumCaseKeyNotFound(allKeys: ["\(rawValue)"])
    }
    return value
  }

}

// MARK: Standard Enum

private struct StandardEnumSchema<
  Value,
  CaseKey: CodingKey,
  each AssociatedValueSchema: ToolInput.Schema
>: InternalSchema {

  let description: String?

  typealias Cases = (repeat EnumSchemaCase<Value, CaseKey, each AssociatedValueSchema>)
  let cases: Cases

  let encodeValue:
    @Sendable (
      Value,
      repeat @escaping ((each AssociatedValueSchema).Value) throws -> Void
    ) throws -> Void

  func encodeSchemaDefinition(
    to encoder: ToolInput.SchemaEncoder<Self>
  ) throws {
    switch style {
    case .singleCase:
      try encodeSingleCaseSchemaDefinition(to: encoder)
    case .noAssociatedValues:
      try encodeNoAssociatedValuesSchemaDefinition(to: encoder)
    case .objectProperties:
      try encodeObjectPropertiesSchemaDefinition(to: encoder)
    }
  }

  private func encodeSingleCaseSchemaDefinition(
    to encoder: ToolInput.SchemaEncoder<Self>
  ) throws {
    /// There should only be a single case
    repeat try (each cases).schema.encodeSchemaDefinition(
      to: ToolInput.SchemaEncoder(
        wrapped: encoder.wrapped,
        descriptionPrefix: combineDescriptions(
          encoder.contextualDescription(description),
          (each cases).description
        )
      )
    )
  }

  private func encodeNoAssociatedValuesSchemaDefinition(
    to encoder: ToolInput.SchemaEncoder<Self>
  ) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)

    var possibleValues: [String] = []
    var valueDescriptions: [String] = []
    for `case` in repeat each cases {
      possibleValues.append(`case`.key.stringValue)

      if let description = `case`.description {
        valueDescriptions.append(" - \(`case`.key): \(description)")
      }
    }

    do {
      let combinedDescription: String?
      switch (description, valueDescriptions.isEmpty) {
      case (nil, false):
        combinedDescription = nil
      case (nil, true):
        combinedDescription = valueDescriptions.joined(separator: "\n")
      case (let description?, false):
        combinedDescription = description
      case (let description?, true):
        combinedDescription = [[description], valueDescriptions]
          .flatMap(\.self)
          .joined(separator: "\n")
      }

      if let description = encoder.contextualDescription(combinedDescription) {
        try container.encode(description, forKey: .description)
      }
    }

    try container.encode(possibleValues, forKey: .enum)
  }

  private func encodeObjectPropertiesSchemaDefinition(
    to encoder: ToolInput.SchemaEncoder<Self>
  ) throws {
    var container = encoder.wrapped.container(keyedBy: SchemaCodingKey.self)

    try container.encodeIfPresent(
      encoder.contextualDescription(description),
      forKey: .description
    )

    try container.encode("object", forKey: .type)
    try container.encode(1, forKey: .minProperties)
    try container.encode(1, forKey: .maxProperties)
    try container.encode(false, forKey: .additionalProperties)

    var properties = container.nestedContainer(keyedBy: CaseKey.self, forKey: .properties)
    for `case` in repeat each cases {
      let encoder = properties.superEncoder(forKey: `case`.key)
      try `case`.schema.encodeSchemaDefinition(
        to: ToolInput.SchemaEncoder(
          wrapped: encoder,
          descriptionPrefix: `case`.description
        )
      )
    }
  }

  func encode(_ value: Value, to encoder: ToolInput.Encoder<Self>) throws {
    try encodeValue(
      value,
      repeat { value in
        switch style {
        case .singleCase:
          try (each cases).schema.encode(value, to: encoder.map())
        case .noAssociatedValues:
          var container = encoder.wrapped.singleValueContainer()
          try container.encode((each cases).key.stringValue)
        case .objectProperties:
          var container = encoder.wrapped.container(keyedBy: CaseKey.self)
          try (each cases).schema.encode(
            value,
            to: ToolInput.Encoder(
              wrapped: container.superEncoder(forKey: (each cases).key)
            )
          )
        }
      }
    )
  }

  func decodeValue(from decoder: ToolInput.Decoder<Self>) throws -> Value {
    switch style {
    case .singleCase:
      for `case` in repeat each cases {
        return `case`.initializer(try `case`.schema.decodeValue(from: decoder.map()))
      }

      assertionFailure()
      throw EnumCaseKeyNotFound(allKeys: [])
    case .noAssociatedValues:
      let stringValue = try decoder.wrapped.singleValueContainer().decode(String.self)
      for `case` in repeat each cases {
        if stringValue == `case`.key.stringValue {
          return try `case`.initializeVoidSchemaValue()
        }
      }
      throw EnumCaseKeyNotFound(allKeys: [stringValue])
    case .objectProperties:
      let container = try decoder.wrapped.container(keyedBy: CaseKey.self)

      for `case` in repeat each cases {
        let key = `case`.key
        if container.contains(key) {
          let associatedValue = try `case`.schema.decodeValue(
            from: ToolInput.Decoder(
              wrapped: container.superDecoder(forKey: key)
            )
          )
          return `case`.initializer(associatedValue)
        }
      }

      throw EnumCaseKeyNotFound(allKeys: container.allKeys.map(\.stringValue))
    }
  }

  private var style: EnumSchemaStyle {
    var caseCount = 0
    var allCaseAssociatedValuesAreVoid = true
    for `case` in repeat each cases {
      caseCount += 1
      if !(`case`.schema is any ToolInput.Schema<Void>) {
        allCaseAssociatedValuesAreVoid = false
      }
    }
    if caseCount == 1 {
      return .singleCase
    } else if allCaseAssociatedValuesAreVoid {
      return .noAssociatedValues
    } else {
      return .objectProperties
    }
  }

}

// MARK: - Implementation Details

private enum EnumSchemaStyle {
  case singleCase
  case noAssociatedValues
  case objectProperties
}

private struct EnumSchemaCase<
  Value,
  CaseKey: CodingKey,
  Schema: ToolInput.Schema
> {
  let key: CaseKey
  let description: String?
  let schema: Schema
  let initializer: @Sendable (Schema.Value) -> Value

  func initializeVoidSchemaValue() throws -> Value {
    guard let value = () as? Schema.Value else {
      throw NonVoidSchema()
    }
    return initializer(value)
  }

  private struct NonVoidSchema: Error {}
}

private enum SchemaCodingKey: CodingKey {
  case type, description, properties, additionalProperties, minProperties, maxProperties, `enum`
}

private struct EnumCaseKeyNotFound: Error {
  let allKeys: [String]
}

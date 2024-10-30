// MARK: - Tool Input

extension Optional: ToolInput where Wrapped: ToolInput {
  public typealias ToolInputSchema = ToolInputOptionalSchema<Wrapped.ToolInputSchema>

  public static var toolInputSchema: ToolInputSchema {
    ToolInputOptionalSchema(wrapped: Wrapped.toolInputSchema)
  }

  public init(
    toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue
  ) throws {
    self =
      try toolInputSchemaDescribedValue
      .map(Wrapped.init(toolInputSchemaDescribedValue:))
  }

  public var toolInputSchemaDescribedValue: Wrapped.ToolInputSchema.DescribedValue? {
    self.map(\.toolInputSchemaDescribedValue)
  }
}

// MARK: - Schema

public struct ToolInputOptionalSchema<WrappedSchema: ToolInputSchema>: ToolInputSchema {

  public typealias DescribedValue = WrappedSchema.DescribedValue?

  public init(
    wrapped: WrappedSchema,
    description: String? = nil
  ) {
    self.wrapped = wrapped
    self.description = description
  }
  public var wrapped: WrappedSchema
  public var description: String?

  public func decodeValue(from decoder: ToolInputDecoder) throws -> WrappedSchema
    .DescribedValue?
  {
    guard try !decoder.decoder.singleValueContainer().decodeNil() else {
      /// A top-level `null` is the only value that represents a `none` optional
      return nil
    }

    let wrappedValueDecoder: Decoder
    if usesObjectWrapper {
      /// If `null` is a valid value for the wrapped schema, we introduce one additional level of heirarchy to avoid ambiguity
      let container = try decoder.decoder.container(keyedBy: ValueCodingKey.self)

      if let wrappedNull = wrapped.metadata.nullValue,
        !container.contains(.nestedOptional)
      {
        /// If `null` is a valid value and the container doesn't contain the `nestedOptional` key, use the null value
        return wrappedNull
      }

      wrappedValueDecoder = try container.superDecoder(forKey: .nestedOptional)
    } else {
      /// Values which are mutually exclusive with `null` are stored in the same level of heirarchy
      wrappedValueDecoder = decoder.decoder
    }

    /// This optional is not `nil`
    return try .some(
      wrapped.decodeValue(from: wrappedValueDecoder)
    )
  }

  public func encode(_ value: DescribedValue, to encoder: ToolInputEncoder) throws {
    guard let value = value else {
      var container = encoder.encoder.singleValueContainer()
      try container.encodeNil()
      return
    }

    if usesObjectWrapper {
      var container = encoder.encoder.container(keyedBy: ValueCodingKey.self)
      try wrapped.encode(value, to: container.superEncoder(forKey: .nestedOptional))
    } else {
      try wrapped.encode(value, to: encoder)
    }
  }

  public func encode(to encoder: ToolInputSchemaEncoder) throws {
    var container = encoder.encoder.container(keyedBy: SchemaCodingKey.self)
    try container.encodeIfPresent(description, forKey: .description)

    let wrappedMetadata = wrapped.metadata
    if usesObjectWrapper {
      /// Since `null` is a valid value for the wrapped schema, we need to wrap the whole thing in an object to avoid ambiguity.
      var anyOfContainer = container.nestedUnkeyedContainer(forKey: .anyOf)
      do {
        /// Encode "null"
        var container = anyOfContainer.nestedContainer(keyedBy: AnyOfElementCodingKey.self)
        try container.encode("null", forKey: .type)
      }
      do {
        /// Encode wrapped schema
        var container = anyOfContainer.nestedContainer(keyedBy: AnyOfElementCodingKey.self)
        try container.encode("object", forKey: .type)
        var properties = container.nestedContainer(
          keyedBy: ValueCodingKey.self, forKey: .properties)
        try wrapped.encode(to: properties.superEncoder(forKey: .nestedOptional))
      }

    } else if let wrappedPrimitive = wrappedMetadata.primitiveRepresentation {
      /// If we aren't using an object wrapper and the wrapped value has a primitive representation, we can encode this schema simply as `["wrappedType", "null"]`
      try container.encode([wrappedPrimitive, "null"], forKey: .type)
    } else {
      /// We have to use `anyOf` to encode the schema
      var anyOfContainer = container.nestedUnkeyedContainer(forKey: .anyOf)
      do {
        /// Encode "null"
        var container = anyOfContainer.nestedContainer(keyedBy: AnyOfElementCodingKey.self)
        try container.encode("null", forKey: .type)
      }
      do {
        /// Encode wrapped schema
        try wrapped.encode(to: anyOfContainer.superEncoder())
      }
    }
  }

  public var metadata: ToolInputSchemaMetadata<ToolInputOptionalSchema<WrappedSchema>> {
    ToolInputSchemaMetadata(
      acceptsNullValue: true,
      nullValue: DescribedValue.none
    )
  }

  /// If the wrapped schema accepts `null` as a valid value, we need to add a wrapper to avoid ambiguity between `null` meaning this optional value is null, and `null` meaning the wrapped value is null.
  fileprivate var usesObjectWrapper: Bool {
    wrapped.metadata.acceptsNullValue
  }
}

private enum ValueCodingKey: String, Swift.CodingKey {
  case nestedOptional
}

private enum AnyOfElementCodingKey: String, Swift.CodingKey {
  case properties, type
}

private enum SchemaCodingKey: String, Swift.CodingKey {
  case type, description, anyOf
}

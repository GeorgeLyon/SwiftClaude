internal import JavaScriptObjectNotation

// MARK: - Definition

/// The single concrete type behind every `schema` witness in the
/// module. Public API only ever exposes it as `some StructuredCodingSchema`; which
/// JSON-schema keywords a value carries is determined by the factory that
/// built it. Kept non-generic so witness manglings never contain pack
/// expansions (which crash the runtime demangler).
@StructuredCodable
struct MetaSchema {

  private var description: String?
  private let type: String?
  private let `enum`: [SchemaCodable]?
  private let const: SchemaCodable?
  private let items: SchemaCodable?
  private let prefixItems: [SchemaCodable]?
  /// `var` so `internallyTaggedBranch(discriminatorPropertyName:caseName:caseSchema:)`
  /// can splice the discriminator property into a case's object schema.
  private var properties: PropertyMap?
  private var required: [String]?
  private let maxProperties: Int?
  private let oneOf: [SchemaCodable]?

  private init(
    description: String? = nil,
    type: String? = nil,
    `enum`: [SchemaCodable]? = nil,
    const: SchemaCodable? = nil,
    items: SchemaCodable? = nil,
    prefixItems: [SchemaCodable]? = nil,
    properties: PropertyMap? = nil,
    required: [String]? = nil,
    maxProperties: Int? = nil,
    oneOf: [SchemaCodable]? = nil
  ) {
    self.description = description
    self.type = type
    self.enum = `enum`
    self.const = const
    self.items = items
    self.prefixItems = prefixItems
    self.properties = properties
    self.required = required
    self.maxProperties = maxProperties
    self.oneOf = oneOf
  }

}

extension MetaSchema: StructuredCodingSchema {

  /// `description` is a stored (and coded) property rather than living inside
  /// a stored metadata value because it is part of the schema's coded
  /// representation; the metadata view is reconstituted around it.
  var metadata: StructuredCodingSchemaMetadata {
    get { StructuredCodingSchemaMetadata(description: description) }
    set { description = newValue.description }
  }

}

// MARK: - Factories

extension MetaSchema {

  /// The type-erased schema: `{}`, optionally with a description.
  static func any(description: String?) -> MetaSchema {
    MetaSchema(description: description)
  }

  static func string(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "string")
  }

  static func boolean(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "boolean")
  }

  static func integer(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "integer")
  }

  static func number(description: String?) -> MetaSchema {
    MetaSchema(description: description, type: "number")
  }

  /// The `enum` keyword: the value must equal one of `values`. The values are
  /// arbitrary JSON values rather than schemas, but `SchemaCodable`'s deferred
  /// encoding erases them just the same. No `type` keyword accompanies them —
  /// the members already pin down the permitted values.
  static func enumeration<Value: StructuredEncodable>(
    description: String?,
    values: [Value]
  ) -> MetaSchema {
    MetaSchema(
      description: description,
      enum: values.map { SchemaCodable($0) }
    )
  }

  /// The `const` keyword: the value must equal `value` exactly. As with
  /// `enum`, no `type` keyword accompanies it.
  static func const<Value: StructuredEncodable>(
    description: String?,
    value: Value
  ) -> MetaSchema {
    MetaSchema(
      description: description,
      const: SchemaCodable(value)
    )
  }

  static func array(
    description: String?,
    items: some StructuredEncodable
  ) -> MetaSchema {
    MetaSchema(
      description: description,
      items: SchemaCodable(items)
    )
  }

  static func tuple<each ElementSchema: StructuredEncodable>(
    description: String?,
    prefixItems: repeat each ElementSchema
  ) -> MetaSchema {
    var encodedPrefixItems: [SchemaCodable] = []
    for prefixItem in repeat each prefixItems {
      encodedPrefixItems.append(SchemaCodable(prefixItem))
    }
    return MetaSchema(
      description: description,
      prefixItems: encodedPrefixItems
    )
  }

  static func object<each PropertySchema: StructuredEncodable>(
    description: String?,
    maxProperties: Int? = nil,
    properties: repeat (StructuredCodingKey, each PropertySchema, Bool)
  ) -> MetaSchema {
    var encodedProperties: [PropertyMap.Property] = []
    var required: [String] = []
    for (name, schema, isRequired) in repeat each properties {
      encodedProperties.append(
        PropertyMap.Property(
          name: name.stringValue,
          schema: SchemaCodable(schema)
        )
      )
      if isRequired {
        required.append(name.stringValue)
      }
    }
    return MetaSchema(
      description: description,
      properties: PropertyMap(properties: encodedProperties),
      required: required.isEmpty ? nil : required,
      maxProperties: maxProperties
    )
  }

  static func oneOf<each Subschema: StructuredEncodable>(
    description: String?,
    subschemas: repeat each Subschema
  ) -> MetaSchema {
    var encodedSubschemas: [SchemaCodable] = []
    for subschema in repeat each subschemas {
      encodedSubschemas.append(SchemaCodable(subschema))
    }
    return MetaSchema(
      description: description,
      oneOf: encodedSubschemas
    )
  }

  static func oneOf(
    description: String?,
    subschemas: [SchemaCodable]
  ) -> MetaSchema {
    MetaSchema(
      description: description,
      oneOf: subschemas
    )
  }

  /// One branch of an internally-tagged enumeration's `oneOf` schema: the
  /// case's object schema with the discriminator property spliced in as the
  /// first required property, pinned to the case's name by `const`. A case
  /// schema is only ever the `MetaSchema` the object machinery builds, but
  /// the cast (and so the splice) is deferred to encoding, where a
  /// hand-written case schema of some other type can surface as an error.
  static func internallyTaggedBranch(
    discriminatorPropertyName: StructuredCodingKey,
    caseName: StructuredCodingKey,
    caseSchema: some StructuredEncodable
  ) -> SchemaCodable {
    SchemaCodable { encoder in
      guard var branch = caseSchema as? MetaSchema else {
        throw MetaSchemaEncodingError.internallyTaggedCaseSchemaIsNotAnObjectSchema
      }
      let discriminator = PropertyMap.Property(
        name: discriminatorPropertyName.stringValue,
        schema: SchemaCodable(
          MetaSchema.const(
            description: nil,
            value: caseName.stringValue
          )
        )
      )
      branch.properties = PropertyMap(
        properties: [discriminator] + (branch.properties?.properties ?? [])
      )
      branch.required = [discriminatorPropertyName.stringValue] + (branch.required ?? [])
      try branch.encode(to: &encoder)
    }
  }

}

// MARK: - Subschemas

extension MetaSchema {

  /// An arbitrary schema value whose encoding is deferred to `encode(to:)`
  /// (which is where errors can surface — `schema` cannot
  /// throw). The capture must be lazy: encoding a `MetaSchema` runs the
  /// generated object machinery, whose `properties()` builds subschemas like
  /// `[SchemaCodable].schema()` — capturing those eagerly would encode a
  /// `MetaSchema` while constructing one and recurse without bound.
  struct SchemaCodable {

    init(_ schema: some StructuredEncodable) {
      encodeSchema = { encoder in
        try schema.encode(to: &encoder)
      }
    }

    fileprivate init(decoded: OpaqueValue) {
      encodeSchema = { encoder in
        encoder.stream.encode(decoded)
      }
    }

    fileprivate init(
      encodeSchema: @escaping (inout StructuredEncoder) throws -> Void
    ) {
      self.encodeSchema = encodeSchema
    }

    fileprivate let encodeSchema: (inout StructuredEncoder) throws -> Void

  }

}

extension MetaSchema.SchemaCodable: StructuredCodable {

  /// A captured schema's own schema erases to the `{}` any-schema.
  static var schema: some StructuredCodingSchema {
    MetaSchema.any(description: nil)
  }

  func encode(to encoder: inout StructuredEncoder) throws {
    try encodeSchema(&encoder)
  }

  static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    try await accessor.initializeValue(
      to: Self(decoded: try await decoder.stream.decodeOpaqueValue())
    )
  }

}

// MARK: - Errors

private enum MetaSchemaEncodingError: Error {
  case internallyTaggedCaseSchemaIsNotAnObjectSchema
}

// MARK: - Property Map

extension MetaSchema {

  /// The `properties` keyword: an object with one dynamically-named property
  /// per schema, which the generated object coding cannot express — names are
  /// `String`s rather than `StructuredCodingKey`s because decoded schemas
  /// have dynamic property names.
  struct PropertyMap {

    struct Property {
      let name: String
      let schema: SchemaCodable
    }
    let properties: [Property]

  }

}

extension MetaSchema.PropertyMap: StructuredCodable {

  /// The property map's own schema erases to the `{}` any-schema.
  static var schema: some StructuredCodingSchema {
    MetaSchema.any(description: nil)
  }

  func encode(to encoder: inout StructuredEncoder) throws {
    try encoder.stream.encodeObject { objectEncoder in
      for property in properties {
        try objectEncoder.encodeProperty(property.name) { stream in
          try stream.withEncoder { encoder in
            try property.schema.encode(to: &encoder)
          }
        }
      }
    }
  }

  static func initialValueForDecoding(isMutable: Bool) -> sending Self? {
    nil
  }

  static func decode<Accessor: StructuredAccessor & ~Escapable>(
    from decoder: inout StructuredDecoder,
    in context: borrowing StructuredDecodingContext,
    using accessor: Accessor
  ) async throws where Accessor.Value == Self {
    let propertyMap = try await decoder.stream.decodeObject { objectDecoder in
      var properties: [Property] = []
      while !objectDecoder.isAtEnd {
        properties.append(
          try await objectDecoder.decodeProperty { name, stream in
            Property(
              name: name,
              schema: MetaSchema.SchemaCodable(decoded: try await stream.decodeOpaqueValue())
            )
          }
        )
      }
      return Self(properties: properties)
    }
    try await accessor.initializeValue(to: propertyMap)
  }

}

internal import JavaScriptObjectNotation

// MARK: - Definition

/// The single concrete type behind every `schema(description:)` witness in the
/// module. Public API only ever exposes it as `some StructuredCodable`; which
/// JSON-schema keywords a value carries is determined by the factory that
/// built it. Kept non-generic so witness manglings never contain pack
/// expansions (which crash the runtime demangler).
@StructuredCodable
struct MetaSchema {

  private let description: String?
  private let type: String?
  private let items: SchemaCodable?
  private let prefixItems: [SchemaCodable]?
  private let properties: PropertyMap?
  private let required: [String]?
  private let maxProperties: Int?
  private let oneOf: [SchemaCodable]?

  private init(
    description: String? = nil,
    type: String? = nil,
    items: SchemaCodable? = nil,
    prefixItems: [SchemaCodable]? = nil,
    properties: PropertyMap? = nil,
    required: [String]? = nil,
    maxProperties: Int? = nil,
    oneOf: [SchemaCodable]? = nil
  ) {
    self.description = description
    self.type = type
    self.items = items
    self.prefixItems = prefixItems
    self.properties = properties
    self.required = required
    self.maxProperties = maxProperties
    self.oneOf = oneOf
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

  /// The unified object schema: value properties and enumeration cases both
  /// lower to `(name, schema, isRequired)` triples — a case is simply a
  /// property that is never required (with `maxProperties: 1` limiting the
  /// object to a single case).
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

}

// MARK: - Subschemas

extension MetaSchema {

  /// An arbitrary schema value whose encoding is deferred to `encode(to:)`
  /// (which is where errors can surface — `schema(description:)` cannot
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

    fileprivate let encodeSchema: (inout StructuredEncoder) throws -> Void

  }

}

extension MetaSchema.SchemaCodable: StructuredCodable {

  /// A captured schema's own schema erases to the `{}` any-schema.
  static func schema(description: String?) -> some StructuredCodable {
    MetaSchema.any(description: description)
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
  static func schema(description: String?) -> some StructuredCodable {
    MetaSchema.any(description: description)
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

// MARK: - Public API

extension SchemaCoding.Support {

  public static func structSchema<Root, each Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    style: StructSchemaStyleStandard = .standard,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, repeat each Property>,
    finishDecoding: @escaping (StructDecoder<repeat (each Property).Value>) -> Root
  ) -> some ObjectSchema<Root> {
    let properties = (repeat each properties().properties)
    let objectSchema = ConcreteObjectSchema(
      description: description,
      properties: repeat (each properties).property
    )
    return objectSchema.wrap { propertyValues in
      finishDecoding(StructDecoder(propertyValues: (repeat each propertyValues)))
    } unwrap: { root in
      (repeat (each properties).accessValue(from: root))
    }
  }

  public static func structSchema<Root, Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    style: StructSchemaStyleStandard = .standard,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, Property>,
    finishDecoding: @escaping (StructSinglePropertyDecoder<Property.Value>) -> Root
  ) -> some ObjectSchema<Root> {
    let properties = properties().properties
    let objectSchema = ConcreteObjectSchema(
      description: description,
      properties: properties.property
    )
    return objectSchema.wrap { propertyValues in
      finishDecoding(StructSinglePropertyDecoder(propertyValues: (propertyValues, ())))
    } unwrap: { root in
      properties.accessValue(from: root)
    }
  }

  public static func structSchema<Root, Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    style: StructSchemaStyleWrapper,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, Property>,
    finishDecoding: @escaping (StructSinglePropertyDecoder<Property.Value>) -> Root
  ) -> some Schema<Root> {
    let properties = properties().properties
    return properties.effectiveSchema.wrap { propertyValues in
      finishDecoding(StructSinglePropertyDecoder(propertyValues: (propertyValues, ())))
    } unwrap: { root in
      properties.accessValue(from: root)
    }
  }

}

// MARK: - Decoder

extension SchemaCoding {

  public typealias StructDecoder = Support.StructDecoder
  public typealias StructSinglePropertyDecoder = Support.StructSinglePropertyDecoder

}

extension SchemaCoding.Support {

  public struct StructDecoder<each PropertyValue> {

    public let propertyValues: (repeat each PropertyValue)

    public func verifyInitializedConstantPropertyValue<Value: Equatable>(
      initialized: Value,
      decoded: Value,
    ) throws {
      guard initialized == decoded else {
        throw Error.constantPropertyValueMismatch
      }
    }

  }

  public struct StructSinglePropertyDecoder<PropertyValue> {

    public let propertyValues: (PropertyValue, ())

    public func verifyInitializedConstantPropertyValue<Value: Equatable>(
      initialized: Value,
      decoded: Value,
    ) throws {
      guard initialized == decoded else {
        throw Error.constantPropertyValueMismatch
      }
    }

  }

}

// MARK: - Properties

extension SchemaCoding.Support {

  public static func structProperty<Root, Schema: SchemaCoding.Schema>(
    name: SchemaCodingKey,
    description: String? = nil,
    keyPath: KeyPath<Root, Schema.Value>,
    schema: Schema
  ) -> StructProperty<Root, some ObjectProperty<Schema.Value>> {
    StructProperty(
      name: name,
      description: description,
      keyPath: keyPath,
      schema: schema
    )
  }

  public static func structProperty<Root, Schema: SchemaCoding.Schema>(
    name: SchemaCodingKey,
    description: String? = nil,
    keyPath: KeyPath<Root, Schema.Value?>,
    schema: OptionalSchema<Schema>
  ) -> StructProperty<Root, some ObjectProperty<Schema.Value?>> {
    StructProperty(
      name: name,
      description: description,
      keyPath: keyPath,
      schema: schema
    )
  }

  public struct StructProperty<Root, Property: ObjectProperty> {
    @_disfavoredOverload
    fileprivate init<Schema: SchemaCoding.Schema>(
      name: SchemaCodingKey,
      description: String?,
      keyPath: KeyPath<Root, Schema.Value>,
      schema: Schema
    ) where Property == DirectObjectProperty<Schema> {
      self.property = Property(
        name: name,
        description: description,
        schema: schema
      )
      self.keyPath = keyPath
      self.effectiveSchema = schema.prependingDescription(description)
    }
    fileprivate init<Schema: SchemaCoding.Schema>(
      name: SchemaCodingKey,
      description: String?,
      keyPath: KeyPath<Root, Schema.Value?>,
      schema: OptionalSchema<Schema>
    ) where Property == OptionalObjectProperty<Schema> {
      self.property = Property(
        name: name,
        description: description,
        schema: schema
      )
      self.keyPath = keyPath
      self.effectiveSchema = schema.prependingDescription(description)
    }
    fileprivate func accessValue(from root: Root) -> Property.Value {
      root[keyPath: keyPath]
    }
    fileprivate let property: Property

    fileprivate let effectiveSchema: Property.EffectiveSchema

    private let keyPath: KeyPath<Root, Property.Value>
  }

}

// MARK: - Properties Builder

extension SchemaCoding.Support {

  @resultBuilder
  public enum StructPropertiesBuilder<Root> {

    public static func buildPartialBlock<First: ObjectProperty>(
      first: StructProperty<Root, First>
    ) -> StructProperties<Root, First> {
      StructProperties(properties: first)
    }

    public static func buildPartialBlock<each Property: ObjectProperty, Next: ObjectProperty>(
      accumulated: StructProperties<Root, repeat each Property>,
      next: StructProperty<Root, Next>
    ) -> StructProperties<Root, repeat each Property, Next> {
      StructProperties(properties: (repeat each accumulated.properties, next))
    }

  }

  public struct StructProperties<Root, each Property: ObjectProperty> {
    let properties: (repeat StructProperty<Root, each Property>)
  }

}

// MARK: - Style

extension SchemaCoding.Support {

  public struct StructSchemaStyleStandard: Style {
    fileprivate init() {}
  }

  public struct StructSchemaStyleWrapper: Style {
    fileprivate init() {}
  }

}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.StructSchemaStyleStandard {
  public static var standard: Self {
    Self()
  }
}

extension SchemaCoding.Support.Style
where Self == SchemaCoding.Support.StructSchemaStyleWrapper {
  public static var wrapper: Self {
    Self()
  }
}

// MARK: - Errors

private enum Error: Swift.Error {
  case constantPropertyValueMismatch
}

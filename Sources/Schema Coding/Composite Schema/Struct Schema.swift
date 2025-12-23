// MARK: - Public API

extension SchemaCoding.Support {

  @_disfavoredOverload
  public static func structSchema<Root, each Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, repeat each Property>,
    initializer: @escaping (StructDecoder<repeat (each Property).Value>) -> Root
  ) -> some ObjectSchema<Root> {
    let properties = (repeat each properties().properties)
    let objectSchema = ConcreteObjectSchema(
      description: description,
      properties: repeat (each properties).property
    )
    return objectSchema.wrap { propertyValues in
      initializer(StructDecoder(propertyValues: (repeat each propertyValues)))
    } unwrap: { root in
      (repeat (each properties).accessValue(from: root))
    }
  }

  public static func structSchema<Root, Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, Property>,
    initializer: @escaping (StructSinglePropertyDecoder<Property.Value>) -> Root
  ) -> some ObjectSchema<Root> {
    let properties = properties().properties
    let objectSchema = ConcreteObjectSchema(
      description: description,
      properties: properties.property
    )
    return objectSchema.wrap { propertyValues in
      initializer(StructSinglePropertyDecoder(propertyValues: (propertyValues, ())))
    } unwrap: { root in
      properties.accessValue(from: root)
    }
  }

}

// MARK: - Decoder

extension SchemaCoding {

  public typealias StructDecoder = SchemaCoding.Support.StructDecoder

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
      property: RequiredObjectProperty(
        name: name,
        description: description,
        schema: schema
      ),
      keyPath: keyPath
    )
  }

  public static func structProperty<Root, Schema: SchemaCoding.Schema>(
    name: SchemaCodingKey,
    description: String? = nil,
    keyPath: KeyPath<Root, Schema.Value?>,
    schema: OptionalSchema<Schema>
  ) -> StructProperty<Root, some ObjectProperty<Schema.Value?>> {
    StructProperty(
      property: OptionalObjectProperty(
        name: name,
        description: description,
        schema: schema.wrappedSchema
      ),
      keyPath: keyPath
    )
  }

  static func structProperty<Root, Value: SchemaCodable & Equatable>(
    name: SchemaCodingKey,
    description: String? = nil,
    constantValue: Value
  ) -> StructProperty<Root, some ObjectProperty<Void>> {
    StructProperty(
      property: ConstantOptionalObjectProperty(
        name: name,
        description: description,
        schema: Value.schema,
        constantValue: constantValue
      )
    )
  }

  public struct StructProperty<Root, Property: ObjectProperty> {
    fileprivate init(
      property: Property
    ) where Property.Value == Void {
      self.property = property
      self.accessor = .constantValue(())
    }
    fileprivate init(
      property: Property,
      keyPath: KeyPath<Root, Property.Value>
    ) {
      self.property = property
      self.accessor = .keyPath(keyPath)
    }
    fileprivate func accessValue(from root: Root) -> Property.Value {
      switch accessor {
      case .keyPath(let keyPath):
        root[keyPath: keyPath]
      case .constantValue(let value):
        value
      }
    }
    fileprivate let property: Property

    private enum Accessor {
      case keyPath(KeyPath<Root, Property.Value>)
      case constantValue(Property.Value)
    }
    private let accessor: Accessor
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

// MARK: - Errors

private enum Error: Swift.Error {
  case constantPropertyValueMismatch
}

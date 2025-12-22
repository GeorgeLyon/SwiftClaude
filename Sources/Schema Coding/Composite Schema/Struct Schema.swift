// MARK: - Schema

extension SchemaCoding.Support {

  public static func structSchema<Root, each Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, repeat each Property>,
    initializer: @escaping @Sendable (repeat (each Property).Value) -> Root
  ) -> some ObjectSchema<Root> {
    let properties = (repeat each properties().properties)
    let objectSchema = ConcreteObjectSchema(
      description: description,
      properties: repeat (each properties).property
    )
    return objectSchema.wrap { propertyValues in
      initializer(repeat each propertyValues)
    } unwrap: { root in
      (repeat (each properties).accessValue(from: root))
    }
  }

}

// MARK: - Property

extension SchemaCoding.Support {

  public static func structProperty<Root, Schema: SchemaCoding.Schema>(
    name: ObjectPropertyName,
    keyPath: KeyPath<Root, Schema.Value> & Sendable,
    schema: Schema
  ) -> StructProperty<Root, some ObjectProperty<Schema.Value>> {
    StructProperty(
      property: objectProperty(
        name: name,
        schema: schema
      ),
      keyPath: keyPath
    )
  }

  public static func structProperty<Root, Schema: SchemaCoding.Schema>(
    name: ObjectPropertyName,
    keyPath: KeyPath<Root, Schema.Value?> & Sendable,
    schema: OptionalSchema<Schema>
  ) -> StructProperty<Root, some ObjectProperty<Schema.Value?>> {
    StructProperty(
      property: objectProperty(
        name: name,
        schema: schema
      ),
      keyPath: keyPath
    )
  }

  public struct StructProperty<Root, Property: ObjectProperty>: Sendable {
    fileprivate init(
      property: Property,
      keyPath: KeyPath<Root, Property.Value> & Sendable
    ) {
      self.property = property
      self.keyPath = keyPath
    }
    fileprivate func accessValue(from root: Root) -> Property.Value {
      root[keyPath: keyPath]
    }
    fileprivate let property: Property
    private let keyPath: KeyPath<Root, Property.Value> & Sendable
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

  public struct StructProperties<Root, each Property: ObjectProperty>: Sendable {
    let properties: (repeat StructProperty<Root, each Property>)
  }

}

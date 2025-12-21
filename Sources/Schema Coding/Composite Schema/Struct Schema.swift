// MARK: - Schema

extension SchemaCoding.Support {

  public static func structSchema<Root, each Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, repeat each Property>,
    initializer: @escaping @Sendable (repeat (each Property).Value) -> Root
  ) -> some ObjectSchema<Root> {
    let properties = (repeat each properties().properties)
    let objectSchema = objectSchema(
      description: description,
      properties: repeat (each properties).property
    )
    return objectSchema.wrap { propertyValues in
      initializer(repeat each propertyValues)
    } unwrap: { root in
      (repeat root[keyPath: (each properties).keyPath])
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
      keyPath: keyPath,
      property: objectProperty(
        name: name,
        schema: schema
      )
    )
  }

  public static func structProperty<Root, Schema: SchemaCoding.Schema>(
    name: ObjectPropertyName,
    keyPath: KeyPath<Root, Schema.Value?> & Sendable,
    schema: OptionalSchema<Schema>
  ) -> StructProperty<Root, some ObjectProperty<Schema.Value?>> {
    StructProperty(
      keyPath: keyPath,
      property: objectProperty(
        name: name,
        schema: schema
      )
    )
  }

  public struct StructProperty<Root, Property: ObjectProperty>: Sendable {
    fileprivate let keyPath: KeyPath<Root, Property.Value> & Sendable
    fileprivate let property: Property
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

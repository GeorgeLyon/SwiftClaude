// MARK: - Schema

extension SchemaCoding.Support {

  public static func structSchema<Root, each Property>(
    representing: Root.Type = Root.self,
    description: String? = nil,
    @StructPropertiesBuilder<Root> properties: () -> StructProperties<Root, repeat each Property>,
    initializer: @escaping @Sendable (StructDecoder<repeat (each Property).Value>) -> Root
  ) -> some ObjectSchema<Root> {
    let properties = (repeat each properties().properties)
    let objectSchema = ConcreteObjectSchema(
      description: description,
      properties: repeat (each properties).property
    )
    return objectSchema.wrap { propertyValues in
      initializer(StructDecoder(propertyValues: repeat each propertyValues))
    } unwrap: { root in
      (repeat (each properties).accessValue(from: root))
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

    public func verifyInitializedConstantPropertyValue<Value: Equatable & Sendable>(
      initialized: Value,
      decoded: Value,
    ) throws {
      guard initialized == decoded else {
        throw Error.constantPropertyValueMismatch(initialized: initialized, decoded: decoded)
      }
    }

  }

}

// MARK: - Properties

extension SchemaCoding.Support {

  public static func structProperty<Root, Schema: SchemaCoding.Schema>(
    name: ObjectPropertyName,
    keyPath: KeyPath<Root, Schema.Value> & Sendable,
    schema: Schema
  ) -> StructProperty<Root, some ObjectProperty<Schema.Value>> {
    StructProperty(
      property: RequiredObjectProperty(
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
      property: OptionalObjectProperty(
        name: name,
        schema: schema.wrappedSchema
      ),
      keyPath: keyPath
    )
  }

  public static func structProperty<Root, Value: SchemaCodable & Equatable & Sendable>(
    name: ObjectPropertyName,
    constantValue: Value
  ) -> StructProperty<Root, some ObjectProperty<Void>> {
    StructProperty(
      property: ConstantOptionalObjectProperty(
        name: name,
        schema: Value.schema,
        constantValue: constantValue
      )
    )
  }

  public struct StructProperty<Root, Property: ObjectProperty>: Sendable {
    fileprivate init(
      property: Property
    ) where Property.Value == Void {
      self.property = property
      self.accessor = .constantValue({ () })
    }
    fileprivate init(
      property: Property,
      keyPath: KeyPath<Root, Property.Value> & Sendable
    ) {
      self.property = property
      self.accessor = .keyPath(keyPath)
    }
    fileprivate func accessValue(from root: Root) -> Property.Value {
      switch accessor {
      case .keyPath(let keyPath):
        root[keyPath: keyPath]
      case .constantValue(let value):
        value()
      }
    }
    fileprivate let property: Property

    private enum Accessor {
      case keyPath(KeyPath<Root, Property.Value> & Sendable)
      case constantValue(@Sendable () -> Property.Value)
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

  public struct StructProperties<Root, each Property: ObjectProperty>: Sendable {
    let properties: (repeat StructProperty<Root, each Property>)
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case constantPropertyValueMismatch(
    initialized: Sendable,
    decoded: Sendable
  )
}

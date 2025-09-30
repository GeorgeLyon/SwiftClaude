// MARK: - API

extension SchemaCoding.Support {

  public static func structSchema<
    Value: Sendable, PropertyName: CodingKey, each Property
  >(
    description: String? = nil,
    propertyName: PropertyName.Type = PropertyName.self,
    @StructPropertiesBuilder<Value, PropertyName>
    properties: () -> StructProperties<Value, repeat each Property>,
    finishDecoding:
      @escaping @Sendable (
        StructDecoder<repeat (each Property).PropertyValue>
      ) throws -> Value
  ) -> some SchemaCoding.ObjectSchema<Value> {
    let properties = properties().properties
    let objectSchema = objectSchema(
      description: description,
      propertyName: PropertyName.self,
      properties: repeat (each properties).objectProperty
    )
    return objectSchema.wrap { properties in
      let decoder = StructDecoder(propertyValues: (repeat each properties))
      return try finishDecoding(decoder)
    } unwrap: { value in
      (repeat value[keyPath: (each properties).keyPath])
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

  public static func structProperty<Value, Name: CodingKey, Schema: SchemaCoding.Schema>(
    name: Name,
    schema: Schema,
    keyPath: KeyPath<Value, Schema.Value> & Sendable
  ) -> StructProperty<Value, some ObjectProperty<Name, Schema.Value>> {
    StructProperty(
      keyPath: keyPath,
      objectProperty: objectProperty(
        name: name,
        schema: schema
      )
    )
  }

  public static func structProperty<Value, Name: CodingKey, WrappedSchema: SchemaCoding.Schema>(
    name: Name,
    schema: OptionalSchema<WrappedSchema>,
    keyPath: KeyPath<Value, WrappedSchema.Value?> & Sendable
  ) -> StructProperty<Value, some ObjectProperty<Name, WrappedSchema.Value?>> {
    StructProperty(
      keyPath: keyPath,
      objectProperty: objectProperty(
        name: name,
        schema: schema
      )
    )
  }

  public struct StructProperty<
    Value,
    ObjectProperty: SchemaCoding.Support.ObjectProperty
  >: Sendable {

    fileprivate let keyPath: KeyPath<Value, ObjectProperty.PropertyValue> & Sendable
    fileprivate let objectProperty: ObjectProperty

    fileprivate init(
      keyPath: KeyPath<Value, ObjectProperty.PropertyValue> & Sendable,
      objectProperty: ObjectProperty
    ) {
      self.keyPath = keyPath
      self.objectProperty = objectProperty
    }

  }

}

extension SchemaCoding.Support {

  public struct StructProperties<Value, each Property: ObjectProperty> {
    let properties: (repeat StructProperty<Value, each Property>)
    fileprivate init(
      _ properties: repeat StructProperty<Value, each Property>
    ) {
      self.properties = (repeat each properties)
    }
  }

  @resultBuilder
  public struct StructPropertiesBuilder<Value, PropertyName: CodingKey> {

    public static func buildBlock() -> StructProperties<Value> {
      StructProperties()
    }

    public static func buildPartialBlock<Property>(
      first: StructProperty<Value, Property>
    ) -> StructProperties<Value, Property> where Property.Name == PropertyName {
      StructProperties(first)
    }

    public static func buildPartialBlock<each Property, NextProperty>(
      accumulated: StructProperties<Value, repeat each Property>,
      next: StructProperty<Value, NextProperty>
    ) -> StructProperties<Value, repeat each Property, NextProperty>
    where NextProperty.Name == PropertyName {
      StructProperties(repeat each accumulated.properties, next)
    }

  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case constantPropertyValueMismatch(
    initialized: Sendable,
    decoded: Sendable
  )
}

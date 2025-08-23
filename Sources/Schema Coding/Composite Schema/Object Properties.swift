// MARK: - Property

extension SchemaCoding.Support {

  public static func objectProperty<Name: CodingKey, Schema: SchemaCoding.Schema>(
    name: Name,
    schema: Schema
  ) -> _RequiredObjectProperty<Name, Schema> {
    _RequiredObjectProperty(
      name: name,
      schema: schema
    )
  }

  public static func objectProperty<Name: CodingKey, WrappedSchema: SchemaCoding.Schema>(
    name: Name,
    schema: OptionalSchema<WrappedSchema>
  ) -> _OptionalObjectProperty<Name, WrappedSchema> {
    _OptionalObjectProperty(
      name: name,
      schema: schema.wrappedSchema,
      metaSchemaContext: SchemaContext(
        descriptionPrefix: schema.description
      )
    )
  }

  static func objectProperty<Name: CodingKey, Value: SchemaCodable & Equatable>(
    name: Name,
    constantValue: Value
  ) -> _RequiredObjectProperty<Name, _ConstantSchema<Value.Schema>> {
    _RequiredObjectProperty(
      name: name,
      schema: _ConstantSchema(
        wrappedSchema: Value.schema,
        constantValue: constantValue
      )
    )
  }

  /// A constant `nil` value is treated as a property which is always omitted
  static func objectProperty<Name: CodingKey, Value: SchemaCodable & Equatable>(
    name: Name,
    constantValue: Value?
  ) -> _OptionalObjectProperty<Name, _ConstantSchema<OptionalSchema<Value.Schema>>> {
    _OptionalObjectProperty(
      name: constantValue == nil ? nil : name,
      schema: _ConstantSchema(
        wrappedSchema: Value?.schema,
        constantValue: constantValue
      )
    )
  }

  public struct ObjectPropertyName {
    let stringValue: String
  }

  public protocol ObjectProperty<Name, PropertyValue>: Sendable {

    init(metadata: ObjectPropertyMetadata<Self>)

    associatedtype Name: CodingKey
    associatedtype Schema: SchemaCoding.Schema
    associatedtype PropertyValue

    var metadata: ObjectPropertyMetadata<Self> { get }

    /// - Returns: `nil` will throw an error when deserializing
    static func coerceToPropertyValue(from schemaValue: Schema.Value?) -> PropertyValue?

    /// - Returns: `nil` means we should omit the property when serializing
    static func coerceToSchemaValue(from propertyValue: PropertyValue) -> Schema.Value?

  }

  public struct ObjectPropertyMetadata<Property: ObjectProperty>: Sendable {
    fileprivate let name: Property.Name?
    fileprivate let schema: Property.Schema
    fileprivate let isRequired: Bool
    fileprivate let metaSchemaContext: SchemaContext
  }

  public struct _RequiredObjectProperty<
    Name: CodingKey,
    Schema: SchemaCoding.Schema
  >: ObjectProperty {
    public typealias PropertyValue = Schema.Value

    public init(metadata: ObjectPropertyMetadata<Self>) {
      assert(metadata.isRequired)
      self.metadata = metadata
    }
    public let metadata: ObjectPropertyMetadata<Self>

    public static func coerceToPropertyValue(from schemaValue: Schema.Value?) -> PropertyValue? {
      schemaValue
    }
    public static func coerceToSchemaValue(from propertyValue: PropertyValue) -> Schema.Value? {
      propertyValue
    }

    init(
      name: Name?,
      schema: Schema
    ) {
      self.init(
        metadata: ObjectPropertyMetadata(
          name: name,
          schema: schema,
          isRequired: true,
          metaSchemaContext: SchemaContext()
        )
      )
    }

  }

  public struct _OptionalObjectProperty<
    Name: CodingKey,
    Schema: SchemaCoding.Schema
  >: ObjectProperty {
    public typealias PropertyValue = Schema.Value?

    public init(metadata: ObjectPropertyMetadata<Self>) {
      assert(!metadata.isRequired)
      self.metadata = metadata
    }
    public let metadata: ObjectPropertyMetadata<Self>

    public static var isRequired: Bool { false }

    public static func coerceToSchemaValue(from propertyValue: PropertyValue) -> Schema.Value? {
      propertyValue
    }
    public static func coerceToPropertyValue(from schemaValue: Schema.Value?) -> PropertyValue? {
      .some(schemaValue)
    }

    init(
      name: Name?,
      schema: Schema,
      metaSchemaContext: SchemaContext = SchemaContext()
    ) {
      self.init(
        metadata: ObjectPropertyMetadata(
          name: name,
          schema: schema,
          isRequired: false,
          metaSchemaContext: metaSchemaContext
        )
      )
    }

  }

}

extension SchemaCoding.Support.ObjectProperty {

  /// If `nil`, this property is always omitted
  var name: Name? {
    metadata.name
  }

  var schema: Schema {
    metadata.schema
  }

  var isRequired: Bool {
    metadata.isRequired
  }

  var metaSchemaContext: SchemaCoding.Support.SchemaContext {
    metadata.metaSchemaContext
  }

  init(
    metadata: SchemaCoding.Support.ObjectPropertyMetadata<Self>,
    schema: Schema
  ) {
    self.init(
      metadata: SchemaCoding.Support.ObjectPropertyMetadata(
        name: metadata.name,
        schema: schema,
        isRequired: metadata.isRequired,
        metaSchemaContext: metadata.metaSchemaContext
      )
    )
  }

  func finishDecoding(
    _ schemaValue: Schema.Value?
  ) throws -> PropertyValue {
    guard
      let propertyValue = Self.coerceToPropertyValue(from: schemaValue)
    else {
      guard let name = name?.stringValue else {
        throw Error.invalidState
      }
      throw Error.missingRequiredProperty(name)
    }
    return propertyValue
  }

}

// MARK: - Builder

extension SchemaCoding.Support {

  @resultBuilder
  public struct ObjectPropertiesBuilder<Name: CodingKey> {

    public static func buildBlock() -> ObjectProperties<Name> {
      ObjectProperties()
    }

    public static func buildPartialBlock<Property>(
      first: Property
    ) -> ObjectProperties<Name, Property>
    where Property.Name == Name {
      ObjectProperties(first)
    }

    public static func buildPartialBlock<each Property, NextProperty>(
      accumulated: ObjectProperties<Name, repeat each Property>,
      next: NextProperty
    ) -> ObjectProperties<Name, repeat each Property, NextProperty>
    where NextProperty.Name == Name {
      ObjectProperties(repeat each accumulated.properties, next)
    }

  }

  public struct ObjectProperties<Name: CodingKey, each Property: ObjectProperty> {
    public let properties: (repeat each Property)
    fileprivate init(
      _ properties: repeat each Property
    ) {
      self.properties = (repeat each properties)
    }
  }

}

// MARK: - Errors

private enum Error: Swift.Error {
  case missingRequiredProperty(String)
  case invalidState
}

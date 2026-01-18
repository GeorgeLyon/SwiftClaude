// MARK: - Object Schema

extension SchemaCoding.Support {

  public protocol ObjectSchema {

    /// TODO: Remove when conforming to Schema
    associatedtype Value

    associatedtype PropertyTypeMetadatas
    static func propertyTypeMetadatas() -> PropertyTypeMetadatas

    associatedtype Properties
    /// This can't be an initializer because it causes a compiler crash
    static func create(from properties: Properties) -> Self
    func properties() -> Properties

    associatedtype PropertyValues
    static func value(from propertyValues: PropertyValues) throws -> Value
    static func propertyValues(from value: Value) -> PropertyValues

  }

  /// This type is only generic so we can create a parameter pack of type metadatas
  public struct PropertyTypeMetadata<Property: ObjectProperty> {
    public init(
      name: SchemaCodingKey
    ) {
      self.name = name
    }
    fileprivate let name: SchemaCodingKey
  }

}

// MARK: - Object Properties Schema

extension SchemaCoding.Support {

  public struct ObjectPropertiesMetaSchema<
    Value: ObjectSchema,
    each ValueProperty: ObjectProperty
  >: ObjectSchema
  where
    Value.PropertyTypeMetadatas == (repeat PropertyTypeMetadata<each ValueProperty>),
    Value.Properties == (repeat each ValueProperty),
    Value.PropertyValues == (repeat (each ValueProperty).EffectiveSchema.Value)
  {

    public typealias PropertyTypeMetadatas = (
      repeat PropertyTypeMetadata<ObjectMetaProperty<each ValueProperty>>
    )
    public static func propertyTypeMetadatas() -> (
      repeat PropertyTypeMetadata<ObjectMetaProperty<each ValueProperty>>
    ) {
      (repeat PropertyTypeMetadata(name: (each Value.propertyTypeMetadatas()).name))
    }

    public typealias Properties = (repeat ObjectMetaProperty<each ValueProperty>)
    public func properties() -> (repeat ObjectMetaProperty<each ValueProperty>) {
      (repeat each _properties)
    }
    private let _properties: (repeat ObjectMetaProperty<each ValueProperty>)

    public typealias PropertyValues = (repeat (each ValueProperty).PropertySchema?)
    public static func value(
      from propertyValues: (repeat (each ValueProperty).PropertySchema?)
    ) throws -> Value {
      Value.create(from: (repeat (each ValueProperty)(propertySchema: each propertyValues)))
    }
    public static func propertyValues(from value: Value) -> PropertyValues {
      (repeat (each value.properties()).propertySchema)
    }

    public static func create(
      from properties: (repeat ObjectMetaProperty<each ValueProperty>)
    ) -> Self {
      Self(properties: (repeat each properties))
    }
    private init(
      properties: (repeat ObjectMetaProperty<each ValueProperty>)
    ) {
      self._properties = (repeat each properties)
    }

  }

}

// MARK: - Object Properties

extension SchemaCoding.Support {

  public protocol ObjectProperty {

    associatedtype EffectiveSchema: Schema

    associatedtype PropertySchema: Schema
    init(propertySchema: PropertySchema?)
    var propertySchema: PropertySchema? { get }

    static func value(from propertyValue: PropertySchema.Value?) -> EffectiveSchema.Value?
    static func propertyValue(from value: EffectiveSchema.Value) -> PropertySchema.Value?

    var metadata: ObjectPropertyMetadata { get }

  }

  public struct ObjectPropertyMetadata {
    fileprivate let isRequired: Bool
  }

}

// MARK: Direct Property

extension SchemaCoding.Support {

  /// A property whose effective schema is equal to the property schema
  public struct DirectObjectProperty<PropertySchema: Schema>: ObjectProperty {

    public typealias EffectiveSchema = PropertySchema

    public let propertySchema: PropertySchema?
    public init(propertySchema: PropertySchema?) {
      self.propertySchema = propertySchema
    }

    public static func value(from propertyValue: PropertySchema.Value?) -> EffectiveSchema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: EffectiveSchema.Value) -> PropertySchema.Value? {
      value
    }

    public var metadata: ObjectPropertyMetadata {
      ObjectPropertyMetadata(isRequired: propertySchema != nil)
    }
  }

}

// MARK: Optional Property

extension SchemaCoding.Support {

  /// A property whose effective schema is the optional schema of the property schema
  /// `nil` is represented by the absence of the property
  public struct OptionalObjectProperty<PropertySchema: Schema>: ObjectProperty {

    public typealias EffectiveSchema = OptionalSchema<PropertySchema>

    public let propertySchema: PropertySchema?
    public init(propertySchema: PropertySchema?) {
      self.propertySchema = propertySchema
    }

    public static func value(from propertyValue: PropertySchema.Value?) -> EffectiveSchema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: EffectiveSchema.Value) -> PropertySchema.Value? {
      value
    }

    public var metadata: ObjectPropertyMetadata {
      ObjectPropertyMetadata(isRequired: false)
    }

  }

}

// MARK: Constant Optional Property

extension SchemaCoding.Support {

  /// A property representing a constant optional value
  /// A `nil` constant value is represented by the absence of the property
  public struct ConstantOptionalObjectProperty<WrappedSchema: Schema>: ObjectProperty
  where WrappedSchema.Value: Equatable {

    public typealias EffectiveSchema = ConstantSchema<OptionalSchema<WrappedSchema>>
    public typealias PropertySchema = ConstantSchema<WrappedSchema>

    public let propertySchema: PropertySchema?
    public init(propertySchema: PropertySchema?) {
      self.propertySchema = propertySchema
    }

    public static func value(from propertyValue: PropertySchema.Value?) -> EffectiveSchema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: EffectiveSchema.Value) -> PropertySchema.Value? {
      value
    }

    public var metadata: ObjectPropertyMetadata {
      ObjectPropertyMetadata(isRequired: propertySchema != nil)
    }

  }

}

// MARK: Object Meta Property

extension SchemaCoding.Support {

  /// A property representing the meta schema of an object property
  public struct ObjectMetaProperty<Property: ObjectProperty>: ObjectProperty {

    public typealias EffectiveSchema = OptionalSchema<Property.PropertySchema.MetaSchema>
    public typealias PropertySchema = Property.PropertySchema.MetaSchema

    public let propertySchema: PropertySchema?
    public init(propertySchema: PropertySchema?) {
      self.propertySchema = propertySchema
    }

    public static func value(from propertyValue: PropertySchema.Value?) -> EffectiveSchema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: EffectiveSchema.Value) -> PropertySchema.Value? {
      value
    }

    public var metadata: ObjectPropertyMetadata {
      ObjectPropertyMetadata(isRequired: propertySchema != nil)
    }

  }

}

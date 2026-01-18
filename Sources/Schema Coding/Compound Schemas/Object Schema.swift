// MARK: - Object Schema

extension SchemaCoding.Support {

  public protocol ObjectSchema {

    /// TODO: Remove when conforming to Schema
    associatedtype Value

    associatedtype PropertyTypeMetadatas
    static func propertyTypeMetadata() -> PropertyTypeMetadatas

    associatedtype Properties
    func properties() -> Properties

    associatedtype PropertyValues
    static func value(from propertyValues: PropertyValues) throws -> Value
    static func propertyValues(from value: Value) -> PropertyValues

  }

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

  public struct ObjectPropertiesSchema<Schema: ObjectSchema> {

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

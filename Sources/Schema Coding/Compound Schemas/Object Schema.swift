private import JSONSupport
private import SchemaCodingSupport

// MARK: - Object Schema

extension SchemaCoding {

  public typealias ObjectSchema = Support.ObjectSchema

}

extension SchemaCoding.Support {

  public protocol ObjectSchema: Schema {

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

    func encodeProperties(of value: Value, to propertiesEncoder: inout ObjectPropertiesEncoder)

    associatedtype PropertiesDecoder: ObjectPropertiesDecoderProtocol
    where PropertiesDecoder.Value == Value
    func beginDecodingPropertyValues(
      from decoder: borrowing Decoder
    ) -> PropertiesDecoder

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

// MARK: - Object Schema Encoding

extension SchemaCoding.Support {

  public struct ObjectPropertiesEncoder: ~Copyable {
    fileprivate var objectEncoder: JSON.ObjectEncoder
  }

}

extension SchemaCoding.Support.ObjectSchema {

  public func encode(_ value: Value, to encoder: inout SchemaCoding.Support.Encoder) {
    encoder.stream.encodeObject { objectEncoder in
      var propertiesEncoder = SchemaCoding.Support.ObjectPropertiesEncoder(
        objectEncoder: objectEncoder
      )
      encodeProperties(of: value, to: &propertiesEncoder)
      objectEncoder = propertiesEncoder.objectEncoder
    }
  }

  public func encodeProperties<each Property: SchemaCoding.Support.ObjectProperty>(
    of value: Value,
    to propertiesEncoder: inout SchemaCoding.Support.ObjectPropertiesEncoder
  )
  where
    PropertyTypeMetadatas == (repeat SchemaCoding.Support.PropertyTypeMetadata<each Property>),
    Properties == (repeat each Property),
    PropertyValues == (repeat (each Property).EffectiveSchema.Value)
  {
    let propertyTypeMetadatas = Self.propertyTypeMetadatas()
    let properties = properties()
    let propertyValues = Self.propertyValues(from: value)

    func encode<T: SchemaCoding.Support.ObjectProperty>(
      name: SchemaCoding.Support.SchemaCodingKey,
      property: T,
      value: T.EffectiveSchema.Value
    ) {
      if let propertySchema = property.propertySchema,
        let value = T.propertyValue(from: value)
      {
        propertiesEncoder.objectEncoder.encodeProperty(name: name) { stream in
          stream.encode(value, using: propertySchema)
        }
      }
    }
    repeat encode(
      name: (each propertyTypeMetadatas).name,
      property: each properties,
      value: each propertyValues
    )
  }

}

// MARK: - Object Schema Decoding

extension SchemaCoding.Support.ObjectSchema {

  public func beginDecodingValue(
    from decoder: borrowing SchemaCoding.Support.Decoder
  ) -> SchemaCoding.Support.ObjectSchemaValueDecodingState<Self> {
    SchemaCoding.Support.ObjectSchemaValueDecodingState(
      propertiesDecoder: beginDecodingPropertyValues(from: decoder)
    )
  }

  public func decodeValue(
    from decoder: inout SchemaCoding.Support.Decoder,
    state: inout SchemaCoding.Support.ObjectSchemaValueDecodingState<Self>
  ) throws -> SchemaCoding.Support.DecodingResult<Value> {
    while true {
      if let propertyDecoder = state.activePropertyDecoder {
        switch try propertyDecoder.decodeValue(from: &decoder).kind {
        case .incomplete:
          return .incomplete
        case .decoded:
          state.activePropertyDecoder = nil
        }
      }

      switch try decoder.stream.decodeObjectComponent(state: &state.objectState) {
      case .incomplete:
        return .incomplete
      case .decoded(.propertyValueStart(let name)):
        guard let propertyDecoder = state.propertiesDecoder.propertyDecodersByName[name] else {
          throw Error.unknownProperty(String(name))
        }
        state.activePropertyDecoder = propertyDecoder
      case .decoded(.end):
        return .decoded(try state.propertiesDecoder.finishDecoding(from: decoder))
      }
    }
  }

  public func beginDecodingPropertyValues<each Property>(
    from decoder: borrowing SchemaCoding.Support.Decoder
  ) -> PropertiesDecoder
  where
    PropertiesDecoder == SchemaCoding.Support.ObjectPropertiesDecoder<
      Self,
      repeat each Property
    >
  {
    SchemaCoding.Support.ObjectPropertiesDecoder(
      properties: (repeat each properties()),
      decoder: decoder
    )
  }

}

extension SchemaCoding.Support {

  public struct ObjectSchemaValueDecodingState<Schema: ObjectSchema> {
    fileprivate var objectState = JSON.ObjectDecodingState()
    fileprivate let propertiesDecoder: Schema.PropertiesDecoder
    fileprivate var activePropertyDecoder: ObjectPropertyDecoderProtocol?
  }

}

// MARK: Object Properties Decoder

extension SchemaCoding.Support {

  public protocol ObjectPropertiesDecoderProtocol {
    associatedtype Value
    func finishDecoding(from decoder: borrowing Decoder) throws -> Value

    var propertyDecodersByName: ObjectPropertyDecodersByName { get }
  }

  public struct ObjectPropertiesDecoder<
    Schema: ObjectSchema,
    each Property: ObjectProperty
  >: ObjectPropertiesDecoderProtocol
  where
    Schema.PropertyTypeMetadatas == (repeat PropertyTypeMetadata<each Property>),
    Schema.Properties == (repeat each Property),
    Schema.PropertyValues == (repeat (each Property).EffectiveSchema.Value)
  {

    public let propertyDecodersByName: ObjectPropertyDecodersByName
    private let propertyDecoders: (repeat ObjectPropertyDecoder<each Property>)

    public func finishDecoding(from decoder: borrowing Decoder) throws -> Schema.Value {
      try Schema.value(from: (repeat (each propertyDecoders).finishDecoding(from: decoder)))
    }

    fileprivate init(
      properties: Schema.Properties,
      decoder: borrowing SchemaCoding.Support.Decoder
    ) {
      self.propertyDecoders =
        (repeat ObjectPropertyDecoder(
          property: each properties,
          decoder: decoder
        ))
      self.propertyDecodersByName = ObjectPropertyDecodersByName(
        typeMetadatas: repeat each Schema.propertyTypeMetadatas(),
        decoders: repeat each propertyDecoders
      )
    }

  }

  struct MergedObjectPropertiesDecoder<
    FirstComponent: ObjectPropertiesDecoderProtocol,
    each OtherComponent: ObjectPropertiesDecoderProtocol
  >: ObjectPropertiesDecoderProtocol {

    let propertyDecodersByName: ObjectPropertyDecodersByName
    private let firstComponent: FirstComponent
    private let otherComponents: (repeat each OtherComponent)

    init(
      _ firstComponent: FirstComponent,
      _ otherComponents: repeat each OtherComponent
    ) {
      self.firstComponent = firstComponent
      self.otherComponents = (repeat each otherComponents)

      do {
        var propertyDecodersByName = firstComponent.propertyDecodersByName
        for component in repeat each otherComponents {
          propertyDecodersByName.merge(with: component.propertyDecodersByName)
        }
        self.propertyDecodersByName = propertyDecodersByName
      }
    }

    func finishDecoding(
      from decoder: borrowing Decoder
    ) throws -> (FirstComponent.Value, repeat (each OtherComponent).Value) {
      try (
        firstComponent.finishDecoding(from: decoder),
        repeat (each otherComponents).finishDecoding(from: decoder)
      )
    }

  }

  public struct ObjectPropertyDecodersByName {

    fileprivate init<each Property: ObjectProperty>(
      typeMetadatas: repeat PropertyTypeMetadata<each Property>,
      decoders: repeat ObjectPropertyDecoder<each Property>
    ) {
      self.init()
      for (name, decoder) in repeat ((each typeMetadatas).name, each decoders) {
        self[Substring(name.stringValue)] = decoder
      }
    }

    subscript(propertyName: Substring) -> ObjectPropertyDecoderProtocol? {
      get { dictionary[propertyName] }
      set {
        guard let newValue else {
          assertionFailure()
          return
        }
        let oldValue = dictionary.updateValue(newValue, forKey: propertyName)
        assert(oldValue == nil)
      }
    }

    mutating func merge(with other: ObjectPropertyDecodersByName) {
      for (key, value) in other.dictionary {
        self[key] = value
      }
    }

    private init() {
      dictionary = [:]
    }
    private var dictionary: [Substring: ObjectPropertyDecoderProtocol]
  }

}

// MARK: Object Property Decoder

extension SchemaCoding.Support {

  protocol ObjectPropertyDecoderProtocol {
    func decodeValue(from decoder: inout Decoder) throws -> DecodingResult<Void>
  }

  fileprivate struct ObjectPropertyDecoder<
    Property: ObjectProperty
  >: ObjectPropertyDecoderProtocol {

    func decodeValue(
      from decoder: inout Decoder
    ) throws -> DecodingResult<Void> {
      guard let propertySchema = property.propertySchema else {
        throw Error.propertyNotOmitted
      }
      return try decoder.arena.withValue(reference) { decodingState in
        var state: Property.PropertySchema.ValueDecodingState
        switch decodingState {
        case .decoded:
          throw Error.propertyAlreadyDecoded
        case .encounteredError(let error):
          throw error
        case .notFound:
          state = propertySchema.beginDecodingValue(from: decoder)
        case .decoding(let s):
          state = s
        }

        do {
          switch try propertySchema.decodeValue(from: &decoder, state: &state).kind {
          case .decoded(let value):
            decodingState = .decoded(value)
            return .decoded
          case .incomplete:
            decodingState = .decoding(state)
            return .incomplete
          }
        } catch {
          decodingState = .encounteredError(error)
          throw error
        }
      }
    }

    func finishDecoding(
      from decoder: borrowing SchemaCoding.Support.Decoder
    ) throws -> Property.EffectiveSchema.Value {
      let propertyValue = try decoder.arena
        .withValue(reference) { decodingState -> Property.PropertySchema.Value? in
          switch decodingState {
          case .encounteredError(let error):
            throw error
          case .decoding:
            throw Error.partiallyDecoded
          case .notFound:
            return nil
          case .decoded(let value):
            return value
          }
        }
      guard let value = Property.value(from: propertyValue) else {
        throw Error.missingProperty
      }
      return value
    }

    fileprivate init(
      property: Property,
      decoder: borrowing Decoder
    ) {
      self.property = property
      self.reference = decoder.arena.push(.notFound)
    }

    private enum DecodingState {
      case notFound
      case decoding(Property.PropertySchema.ValueDecodingState)
      case decoded(Property.PropertySchema.Value)
      case encounteredError(Swift.Error)
    }

    private let property: Property
    private let reference: Arena.Reference<DecodingState>

  }

}

// MARK:- Object Meta Schema

extension SchemaCoding.Support.ObjectSchema {

  public func _metaSchema<each Property: SchemaCoding.Support.ObjectProperty>()
    -> SchemaCoding.Support.ObjectMetaSchema<Self, repeat each Property>
  {
    SchemaCoding.Support.ObjectMetaSchema(value: self)
  }

}

extension SchemaCoding.Support {

  public struct ObjectMetaSchema<
    Value: ObjectSchema,
    each ValueProperty: ObjectProperty
  >: ObjectSchema
  where
    Value.PropertyTypeMetadatas == (repeat PropertyTypeMetadata<each ValueProperty>),
    Value.Properties == (repeat each ValueProperty),
    Value.PropertyValues == (repeat (each ValueProperty).EffectiveSchema.Value)
  {

    public typealias PropertiesProperty = DirectObjectProperty<
      ObjectMetaSchemaPropertiesSchema<
        Value,
        repeat each ValueProperty
      >
    >

    public typealias PropertyTypeMetadatas = (
      PropertyTypeMetadata<PropertiesProperty>
    )
    public static func propertyTypeMetadatas() -> PropertyTypeMetadatas {
      (PropertyTypeMetadata(name: .properties))
    }

    public typealias Properties = (PropertiesProperty)
    public static func create(from properties: Properties) -> Self {
      Self(propertiesProperty: properties)
    }
    public func properties() -> Properties {
      (propertiesProperty)
    }

    public typealias PropertyValues = (PropertiesProperty.EffectiveSchema.Value)
    public static func value(
      from propertyValues: (PropertiesProperty.EffectiveSchema.Value)
    ) throws -> Value {
      propertyValues
    }
    public static func propertyValues(from value: Value) -> PropertyValues {
      value
    }

    public typealias ValueDecodingState = ObjectSchemaValueDecodingState<Self>

    public typealias PropertiesDecoder = SchemaCoding.Support.ObjectPropertiesDecoder<
      Self,
      PropertiesProperty
    >

    public typealias MetaSchema = ObjectMetaSchema<
      Self,
      PropertiesProperty
    >
    public var metaSchema: MetaSchema {
      _metaSchema()
    }

    fileprivate init(
      value: Value
    ) {
      let propertyMetaSchemas = (repeat (each value.properties()).propertySchema?.metaSchema)
      let properties =
        (repeat ObjectMetaProperty<each ValueProperty>(
          propertySchema: each propertyMetaSchemas))
      self.propertiesProperty = PropertiesProperty(
        propertySchema: ObjectMetaSchemaPropertiesSchema(
          properties: (repeat each properties)
        )
      )
    }

    private init(
      propertiesProperty: PropertiesProperty
    ) {
      self.propertiesProperty = propertiesProperty
    }

    public var metadata = SchemaMetadata()
    private let propertiesProperty: PropertiesProperty

  }

}

// MARK: Object Meta Schema Properties

extension SchemaCoding.Support {

  public struct ObjectMetaSchemaPropertiesSchema<
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
    fileprivate init(
      properties: (repeat ObjectMetaProperty<each ValueProperty>)
    ) {
      self._properties = (repeat each properties)
    }

    public typealias PropertiesDecoder = SchemaCoding.Support.ObjectPropertiesDecoder<
      Self,
      repeat ObjectMetaProperty<each ValueProperty>
    >

    public typealias MetaSchema = ObjectMetaSchema<
      Self,
      repeat ObjectMetaProperty<each ValueProperty>
    >
    public var metaSchema: MetaSchema {
      _metaSchema()
    }

    public var metadata = SchemaMetadata()

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

// MARK: - Errors

private enum Error: Swift.Error {
  case propertyAlreadyDecoded
  case propertyNotOmitted
  case partiallyDecoded
  case missingProperty
  case unknownProperty(String)
}

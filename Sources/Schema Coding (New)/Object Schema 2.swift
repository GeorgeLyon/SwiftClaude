import JSONSupport
import SchemaCodingSupport

// MARK: - Object Schema

extension SchemaCoding {

  typealias ObjectSchema = Support.ObjectSchema

}

extension SchemaCoding.Support {

  protocol ObjectSchema: Schema {

    init(properties: Properties)

    associatedtype PropertyNames
    static func propertyNames() -> PropertyNames

    associatedtype Properties
    func properties() -> Properties

    associatedtype PropertyValues
    static func value(from propertyValues: PropertyValues) throws -> Value
    static func propertyValues(from value: Value) -> PropertyValues

    func encodePropertyValues(_ values: PropertyValues, to encoder: inout ObjectPropertiesEncoder)

    associatedtype PropertiesDecoder: ObjectPropertiesDecoderProtocol
    where PropertiesDecoder.Value == Value
    func beginDecodingPropertyValues(
      from decoder: borrowing Decoder
    ) -> PropertiesDecoder

  }

}

extension SchemaCoding.Support {

  fileprivate struct NamedProperty<Property: ObjectProperty> {
    let name: SchemaCodingKey
    let property: Property
  }

}

extension SchemaCoding.Support.ObjectSchema {

  fileprivate func namedProperties<each Property>(

  ) -> (repeat SchemaCoding.Support.NamedProperty<each Property>)
  where
    PropertyNames == (repeat SchemaCoding.Support.PropertyName<each Property>),
    Properties == (repeat each Property)
  {
    fatalError()
  }

}

// MARK: - Object Property

extension SchemaCoding.Support {

  public protocol ObjectProperty {

    associatedtype Schema: SchemaCoding.Schema

    associatedtype PropertySchema: SchemaCoding.Schema
    init(propertySchema: PropertySchema?)
    var propertySchema: PropertySchema? { get }

    static func value(from propertyValue: PropertySchema.Value?) -> Schema.Value?
    static func propertyValue(from value: Schema.Value) -> PropertySchema.Value?

  }

  public struct PropertyName<Property: ObjectProperty>: ExpressibleByStringLiteral {
    public init(stringLiteral value: StaticString) {
      name = SchemaCodingKey(stringLiteral: value)
    }
    fileprivate func map<T>(to type: T.Type = T.self) -> PropertyName<T> {
      PropertyName<T>(name: name)
    }
    fileprivate let name: SchemaCodingKey

    private init(name: SchemaCodingKey) {
      self.name = name
    }
  }

}

extension SchemaCoding.Support {

  public struct DirectObjectProperty<Schema: SchemaCoding.Schema>: ObjectProperty {

    public typealias PropertySchema = Schema

    public let propertySchema: PropertySchema?

    public init(
      propertySchema: Schema?
    ) {
      self.propertySchema = propertySchema
    }

    public static func value(from propertyValue: PropertySchema.Value?) -> Schema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: Schema.Value) -> PropertySchema.Value? {
      value
    }

  }

}

extension SchemaCoding.Support {

  public struct OptionalObjectProperty<PropertySchema: SchemaCoding.Schema>: ObjectProperty {

    public typealias Schema = OptionalSchema<PropertySchema>

    public let propertySchema: PropertySchema?

    public init(propertySchema: PropertySchema?) {
      self.propertySchema = propertySchema
    }

    public static func value(from propertyValue: PropertySchema.Value?) -> Schema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: Schema.Value) -> PropertySchema.Value? {
      value
    }

    fileprivate init(
      schema: Schema?
    ) {
      self.propertySchema = schema.map { schema in
        schema.wrappedSchema
          .prependingDescription(schema.description)
      }
    }

  }

}

extension SchemaCoding.Support {

  public struct ConstantOptionalObjectProperty<WrappedSchema: SchemaCoding.Schema>: ObjectProperty
  where WrappedSchema.Value: Equatable {

    public typealias Schema = ConstantSchema<OptionalSchema<WrappedSchema>>
    public typealias PropertySchema = ConstantSchema<WrappedSchema>

    public let propertySchema: ConstantSchema<WrappedSchema>?

    public init(
      propertySchema: PropertySchema?
    ) {
      self.propertySchema = propertySchema
    }

    fileprivate init(
      schema: Schema?
    ) {
      if let schema,
        let constantValue = schema.constantValue
      {
        self.propertySchema =
          PropertySchema(
            wrappedSchema: schema.wrappedSchema.wrappedSchema
              .prependingDescription(schema.wrappedSchema.description),
            description: schema.description,
            constantValue: constantValue
          )
      } else {
        self.propertySchema = nil
      }

    }

    public static func value(from propertyValue: PropertySchema.Value?) -> Schema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: Schema.Value) -> PropertySchema.Value? {
      value
    }

  }

}

// MARK: - Encoding

extension SchemaCoding.Support.ObjectSchema {

  public func encode<each Property: SchemaCoding.Support.ObjectProperty>(
    _ value: Value,
    to encoder: inout SchemaCoding.Support.Encoder
  )
  where
    Properties == (repeat each Property),
    PropertyValues == (repeat (each Property).Schema.Value)
  {
    fatalError()
  }

  func encodePropertyValues<each Property: SchemaCoding.Support.ObjectProperty>(
    _ values: PropertyValues,
    to encoder: inout SchemaCoding.Support.ObjectPropertiesEncoder
  )
  where
    PropertyNames == (repeat SchemaCoding.Support.PropertyName<each Property>),
    Properties == (repeat each Property),
    PropertyValues == (repeat (each Property).Schema.Value)
  {
    fatalError()
  }

}

extension SchemaCoding.Support {

  struct ObjectPropertiesEncoder: ~Copyable {
    var objectEncoder: JSON.ObjectEncoder
  }

}

// MARK: - Decoding

extension SchemaCoding.Support.ObjectSchema {

  public func beginDecodingValue(
    from decoder: borrowing SchemaCoding.Support.Decoder
  ) -> SchemaCoding.Support.ObjectSchemaValueDecodingState<Self> {
    fatalError()
  }

  public func decodeValue(
    from decoder: inout SchemaCoding.Support.Decoder,
    state: inout SchemaCoding.Support.ObjectSchemaValueDecodingState<Self>
  ) throws -> SchemaCoding.Support.DecodingResult<Value> {
    fatalError()
  }

  public func beginDecodingPropertyValues<each Property>(
    from decoder: borrowing SchemaCoding.Support.Decoder
  )
    -> SchemaCoding.Support.ObjectPropertiesDecoder<
      Self,
      repeat each Property
    >
  {
    fatalError()
  }

}

extension SchemaCoding.Support {

  struct ObjectSchemaValueDecodingState<Schema: ObjectSchema> {
    fileprivate var objectState = JSON.ObjectDecodingState()
    fileprivate let propertiesDecoder: Schema.PropertiesDecoder
    fileprivate var activeDecoder: ObjectPropertyDecoderProtocol?
  }

}

extension SchemaCoding.Support.ObjectProperty {

  func beginDecoding(
    from decoder: borrowing SchemaCoding.Support.Decoder
  ) -> SchemaCoding.Support.ObjectPropertyDecoder<Self> {
    SchemaCoding.Support.ObjectPropertyDecoder<Self>(
      property: self,
      decoder: decoder
    )
  }

}

extension SchemaCoding.Support {

  protocol ObjectPropertyDecoderProtocol {
    func decodeValue(from decoder: inout Decoder) throws -> DecodingResult<Void>
  }

  struct ObjectPropertyDecoder<Property: ObjectProperty>: ObjectPropertyDecoderProtocol {

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
    ) throws -> Property.Schema.Value {
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

extension SchemaCoding.Support {

  protocol ObjectPropertiesDecoderProtocol {
    associatedtype Value
    func finishDecoding(from decoder: borrowing Decoder) throws -> Value

    var propertyDecodersByName: PropertyDecodersByName { get }
  }

  struct ObjectPropertiesDecoder<
    Schema: ObjectSchema,
    each Property: ObjectProperty
  >: ObjectPropertiesDecoderProtocol
  where
    Schema.PropertyNames == (repeat PropertyName<each Property>),
    Schema.Properties == (repeat each Property),
    Schema.PropertyValues == (repeat (each Property).Schema.Value)
  {

    let propertyDecodersByName: PropertyDecodersByName
    private let propertyDecoders: (repeat ObjectPropertyDecoder<each Property>)

    init(
      propertyNames: Schema.PropertyNames,
      properties: Schema.Properties,
      decoder: borrowing SchemaCoding.Support.Decoder
    ) {
      fatalError()
    }

    func finishDecoding(from decoder: borrowing Decoder) throws -> Schema.Value {
      fatalError()
    }

  }

  struct MergedObjectPropertiesDecoder<
    FirstComponent: ObjectPropertiesDecoderProtocol,
    each OtherComponent: ObjectPropertiesDecoderProtocol
  >: ObjectPropertiesDecoderProtocol {

    let propertyDecodersByName: PropertyDecodersByName
    private let firstComponent: FirstComponent
    private let otherComponents: (repeat each OtherComponent)

    init(
      _ firstComponent: FirstComponent,
      _ otherComponents: repeat each OtherComponent
    ) {
      fatalError()
    }

    func finishDecoding(
      from decoder: borrowing Decoder
    ) throws -> (FirstComponent.Value, repeat (each OtherComponent).Value) {
      fatalError()
    }

  }

  struct PropertyDecodersByName {

    init<each Property: ObjectProperty>(
      propertyNames: repeat PropertyName<each Property>,
      decoders: repeat ObjectPropertyDecoder<each Property>
    ) {
      fatalError()
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

    mutating func merge(_ other: PropertyDecodersByName) {
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

// MARK: - Meta Schema

extension SchemaCoding.Support.ObjectSchema {

  public var metaSchema: SchemaCoding.Support.ObjectMetaSchema<Self> {
    fatalError()
  }

}

extension SchemaCoding.Support {

  struct ObjectMetaSchema<Value: ObjectSchema>: WrapperSchema {
    var wrappedSchema: UnimplementedSchema<Never>
    static func wrap(_ wrappedValue: Never) -> Value {
    }
    static func unwrap(_ value: Value) -> Never {
      fatalError()
    }
  }

  struct ObjectPropertiesMetaSchema<
    Value: ObjectSchema,
    each ValueProperty: ObjectProperty
  >: ObjectSchema
  where
    Value.PropertyNames == (repeat PropertyName<each ValueProperty>),
    Value.Properties == (repeat each ValueProperty)
  {
    typealias Properties = (
      repeat ObjectMetaProperty<(each ValueProperty).PropertySchema.MetaSchema>
    )

    typealias PropertyNames = (
      repeat PropertyName<ObjectMetaProperty<(each ValueProperty).PropertySchema.MetaSchema>>
    )
    static func propertyNames() -> PropertyNames {
      fatalError()
    }

    // private let _properties: Properties

    init(
      properties: Properties
    ) {
      fatalError()
    }

    func properties() -> Properties {
      fatalError()
    }

    typealias PropertyValues = (repeat (each ValueProperty).PropertySchema?)
    static func value(from propertyValues: PropertyValues) throws -> Value {
      fatalError()
    }
    static func propertyValues(from value: Value) -> PropertyValues {
      fatalError()
    }

    typealias ValueDecodingState = ObjectSchemaValueDecodingState<Self>

    typealias PropertiesDecoder = ObjectPropertiesDecoder<
      Self,
      repeat ObjectMetaProperty<(each ValueProperty).PropertySchema.MetaSchema>
    >

    var metadata = SchemaMetadata()

  }

  struct ObjectMetaProperty<PropertySchema: SchemaCoding.Schema>: ObjectProperty {

    public typealias Schema = OptionalSchema<PropertySchema>

    public let propertySchema: PropertySchema?

    public init(
      propertySchema: PropertySchema?
    ) {
      self.propertySchema = propertySchema
    }

    public static func value(from propertyValue: PropertySchema.Value?) -> Schema.Value? {
      propertyValue
    }
    public static func propertyValue(from value: Schema.Value) -> PropertySchema.Value? {
      value
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

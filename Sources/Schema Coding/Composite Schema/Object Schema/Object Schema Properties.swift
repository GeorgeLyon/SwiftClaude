import JSONSupport

extension SchemaCoding.Support {

  public protocol ObjectSchemaProperties: Sendable {

    associatedtype Value

    func encodeProperties(
      of value: Value,
      to encoder: inout ObjectPropertiesEncoder
    )

    func beginDecodingProperties(
      from decoder: borrowing Decoder
    ) -> ObjectPropertiesDecodingState<Value>

    associatedtype MetaProperties: ObjectSchemaProperties where MetaProperties.Value == Self
    var metaProperties: MetaProperties { get }

    var metadata: ObjectPropertiesMetadata { get }

  }

  public struct ObjectPropertiesEncoder: ~Copyable {
    var encoder: JSON.ObjectEncoder
  }

  public struct ObjectPropertiesDecodingState<Value> {
    fileprivate let decoders: ObjectPropertyDecoders
    fileprivate let finishDecoding: (borrowing Decoder) throws -> Value
  }

  public struct ObjectPropertiesMetadata {
    let requiredPropertyNames: [String]
  }

  fileprivate struct ObjectPropertyDecoders {
    subscript(_ name: Substring) -> (any ObjectPropertyDecoder)? {
      decoders[name]
    }

    fileprivate init() {
      decoders = [:]
    }
    fileprivate init<each Decoder: ObjectPropertyDecoder>(
      _ decoders: repeat each Decoder
    ) {
      self.init()
      self.insert(repeat each decoders)
    }
    fileprivate mutating func insert(
      _ decoders: ObjectPropertyDecoders
    ) {
      for (key, decoder) in decoders.decoders {
        set(decoder, forKey: key)
      }
    }
    fileprivate mutating func insert<each Decoder: ObjectPropertyDecoder>(
      _ decoders: repeat each Decoder
    ) {
      for decoder in repeat each decoders {
        set(decoder, forKey: Substring(decoder.propertyName))
      }
    }
    private mutating func set(
      _ decoder: any ObjectPropertyDecoder,
      forKey key: Substring
    ) {
      let isNewProperty =
        self.decoders.updateValue(
          decoder,
          forKey: key)
        == nil
      assert(isNewProperty)
    }
    private var decoders: [Substring: any ObjectPropertyDecoder]
  }

}

// MARK: - Object Schema Properties Schema

extension SchemaCoding.Support.ObjectSchemaProperties {

  typealias Schema = SchemaCoding.Support.ObjectSchemaPropertiesSchema<Self>
  var schema: Schema {
    Schema(properties: self)
  }

}

extension SchemaCoding.Support {

  struct ObjectSchemaPropertiesSchema<Properties: ObjectSchemaProperties>: Schema {

    typealias Value = Properties.Value

    func encode(_ value: Value, to encoder: inout Encoder) {
      encoder.stream.encodeObject { encoder in
        var objectEncoder = ObjectPropertiesEncoder(encoder: encoder)
        properties.encodeProperties(of: value, to: &objectEncoder)
        encoder = objectEncoder.encoder
      }
    }

    struct ValueDecodingState {
      init(propertiesState: ObjectPropertiesDecodingState<Value>) {
        self.propertiesState = propertiesState
      }
      mutating func decode(from decoder: inout Decoder) throws -> DecodingResult<Value> {
        while true {
          if let propertyDecoder = activePropertyDecoder {
            switch try propertyDecoder.decode(from: &decoder).kind {
            case .incomplete:
              return .incomplete
            case .decoded:
              activePropertyDecoder = nil
            }
          }

          switch try decoder.stream.decodeObjectComponent(state: &objectState) {
          case .incomplete:
            return .incomplete
          case .decoded(.propertyValueStart(let name)):
            guard let propertyDecoder = propertiesState.decoders[name] else {
              throw Error.unknownProperty(name: String(name))
            }
            activePropertyDecoder = propertyDecoder
          case .decoded(.end):
            return .decoded(try propertiesState.finishDecoding(decoder))
          }
        }
      }
      fileprivate let propertiesState: ObjectPropertiesDecodingState<Value>
      fileprivate var objectState = JSON.ObjectDecodingState()
      fileprivate var activePropertyDecoder: (any ObjectPropertyDecoder)?
    }

    func beginDecodingValue(from decoder: borrowing Decoder) -> ValueDecodingState {
      ValueDecodingState(
        propertiesState: properties.beginDecodingProperties(from: decoder)
      )
    }

    func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      try state.decode(from: &decoder)
    }

    typealias MetaSchema = WrapperSchema<
      Self,
      ObjectSchemaPropertiesSchema<Properties.MetaProperties>
    >
    func metaSchema(
      in context: SchemaContext
    ) -> MetaSchema {
      ObjectSchemaPropertiesSchema<Properties.MetaProperties>(
        properties: properties.metaProperties
      ).wrap { propertiesSchema in
        Self(properties: properties)
      } unwrap: { container in
        container.properties
      }
    }

    let properties: Properties

  }

}

// MARK: - Tuple Object Schema Properties

extension SchemaCoding.Support {

  struct TupleObjectSchemaProperties<each Property: ObjectProperty>:
    ObjectSchemaProperties
  {

    typealias Value = (repeat (each Property).Value)

    func encodeProperties(
      of values: Value,
      to encoder: inout ObjectPropertiesEncoder
    ) {
      for (value, property) in repeat (each values, each properties) {
        property.encode(value, to: &encoder)
      }
    }

    func beginDecodingProperties(
      from decoder: borrowing Decoder
    ) -> ObjectPropertiesDecodingState<Value> {
      let decoders = (repeat (each properties).beginDecoding(from: decoder))
      return ObjectPropertiesDecodingState(
        decoders: ObjectPropertyDecoders(repeat each decoders),
        finishDecoding: { decoder in
          try (repeat (each decoders).finishDecoding(from: decoder))
        }
      )
    }

    typealias MetaProperties = WrapperObjectSchemaProperties<
      Self,
      TupleObjectSchemaProperties<repeat (each Property).MetaProperty>
    >
    var metaProperties: MetaProperties {
      WrapperObjectSchemaProperties(
        wrappedProperties: TupleObjectSchemaProperties<
          repeat (each Property).MetaProperty
        >(repeat (each properties).metaProperty),
        wrap: { properties in
          Self(repeat each properties)
        },
        unwrap: { wrapper in
          (repeat each wrapper.properties)
        }
      )
    }

    var metadata: ObjectPropertiesMetadata {
      var requiredPropertyNames: [String] = []
      for property in repeat each properties {
        if property.isRequired {
          requiredPropertyNames.append(property.name.stringValue)
        }
      }
      return ObjectPropertiesMetadata(
        requiredPropertyNames: requiredPropertyNames
      )
    }

    init(
      _ properties: repeat each Property
    ) {
      self.properties = (repeat each properties)
    }
    let properties: (repeat each Property)

  }

}

// MARK: - Wrapper Object Schema Properties

extension SchemaCoding.Support {

  struct WrapperObjectSchemaProperties<Value, WrappedProperties: ObjectSchemaProperties>:
    ObjectSchemaProperties
  {

    func encodeProperties(
      of value: Value, to encoder: inout SchemaCoding.Support.ObjectPropertiesEncoder
    ) {
      wrappedProperties.encodeProperties(of: unwrap(value), to: &encoder)
    }

    func beginDecodingProperties(
      from decoder: borrowing Decoder
    ) -> ObjectPropertiesDecodingState<Value> {
      let wrappedState = wrappedProperties.beginDecodingProperties(from: decoder)
      return ObjectPropertiesDecodingState(
        decoders: wrappedState.decoders,
        finishDecoding: { decoder in
          try wrap(wrappedState.finishDecoding(decoder))
        }
      )
    }

    var metaProperties: WrapperObjectSchemaProperties<Self, WrappedProperties.MetaProperties> {
      MetaProperties(
        wrappedProperties: wrappedProperties.metaProperties,
        wrap: { wrapped in
          Self(
            wrappedProperties: wrapped,
            wrap: wrap,
            unwrap: unwrap
          )
        },
        unwrap: { wrapper in
          wrapper.wrappedProperties
        }
      )
    }

    var metadata: ObjectPropertiesMetadata {
      wrappedProperties.metadata
    }

    init(
      wrappedProperties: WrappedProperties,
      wrap: @escaping @Sendable (WrappedProperties.Value) throws -> Value,
      unwrap: @escaping @Sendable (Value) -> WrappedProperties.Value
    ) {
      self.wrappedProperties = wrappedProperties
      self.wrap = wrap
      self.unwrap = unwrap
    }
    private let wrappedProperties: WrappedProperties
    private let wrap: @Sendable (WrappedProperties.Value) throws -> Value
    private let unwrap: @Sendable (Value) -> WrappedProperties.Value

  }

}

// MARK: - Composite Object Schema Properties

extension SchemaCoding.Support {

  struct CompositeObjectSchemaProperties<each Component: ObjectSchemaProperties>:
    ObjectSchemaProperties
  {

    typealias Value = (repeat (each Component).Value)

    func encodeProperties(
      of values: Value,
      to encoder: inout ObjectPropertiesEncoder
    ) {
      /// - note: Does not check for duplicate property names
      for (value, component) in repeat (each values, each components) {
        component.encodeProperties(of: value, to: &encoder)
      }
    }

    func beginDecodingProperties(
      from decoder: borrowing Decoder
    ) -> ObjectPropertiesDecodingState<Value> {
      let componentStates = (repeat (each components).beginDecodingProperties(from: decoder))
      var decoders = ObjectPropertyDecoders()
      for componentState in repeat each componentStates {
        decoders.insert(componentState.decoders)
      }
      return ObjectPropertiesDecodingState(
        decoders: decoders,
        finishDecoding: { decoder in
          try (repeat (each componentStates).finishDecoding(decoder))
        }
      )
    }

    typealias MetaProperties = WrapperObjectSchemaProperties<
      Self,
      CompositeObjectSchemaProperties<repeat (each Component).MetaProperties>
    >
    var metaProperties: MetaProperties {
      MetaProperties(
        wrappedProperties: CompositeObjectSchemaProperties<repeat (each Component).MetaProperties>(
          repeat (each components).metaProperties
        ),
        wrap: { components in
          Self(repeat each components)
        },
        unwrap: { wrapper in
          (repeat each wrapper.components)
        }
      )
    }

    var metadata: ObjectPropertiesMetadata {
      var requiredPropertyNames: [String] = []
      for component in repeat each components {
        requiredPropertyNames.append(contentsOf: component.metadata.requiredPropertyNames)
      }
      return ObjectPropertiesMetadata(requiredPropertyNames: requiredPropertyNames)
    }

    init(
      _ components: repeat each Component
    ) {
      self.components = (repeat each components)
    }
    private let components: (repeat each Component)

  }

}

// MARK: - Implementation Details

private enum Error: Swift.Error {
  case unknownProperty(name: String)
}

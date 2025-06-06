import JSONSupport

extension SchemaSupport {

  public static func schema<Wrapped: SchemaCodable>(
    representing: Wrapped?.Type = Wrapped?.self
  ) -> some Schema<Wrapped?> {
    OptionalSchema(
      wrappedSchema: Wrapped.schema
    )
  }

}

extension Optional: SchemaCodable where Wrapped: SchemaCodable {

  public static var schema: some Schema<Self> {
    SchemaSupport.schema()
  }

}

// MARK: - Internal Logic

/**
 Optionals have different representations based on whether or not they are properties of an object.
 Object properties have a special representation which **does not** accept `null`, instead requiring the property to be omitted.
 Optionals outside of objects are represented as a value that can either be `null` or the wrapped value.
 If the wrapped value is itself nullable and thr optional is not an object property, we add a wrapper struct to disambiguate between wrapping and wrapped `nil`.
 */

// MARK: - Implementation Details

protocol OptionalSchemaProtocol<Value>: InternalSchema {

  var valueWhenOmitted: Value { get }

  func shouldOmit(_ value: Value) -> Bool

  func encodeWrappedSchemaDefinition(
    to stream: inout JSON.EncodingStream,
    descriptionPrefix: String?,
    descriptionSuffix: String?
  )

}

private struct OptionalSchema<WrappedSchema: Schema>: OptionalSchemaProtocol {

  let wrappedSchema: WrappedSchema

  typealias Value = WrappedSchema.Value?

  func encodeSchemaDefinition(to encoder: inout SchemaSupport.SchemaEncoder) {
    let description = encoder.contextualDescription(nil)
    encoder.stream.encodeObject { encoder in
      if let description {
        encoder.encodeProperty(name: "description") { $0.encode(description) }
      }

      if let leafType = (wrappedSchema as? any LeafSchema)?.type {
        encoder.encodeProperty(name: "type") { encoder in
          encoder.encodeArray { encoder in
            encoder.encodeElement { $0.encode("null") }
            encoder.encodeElement { $0.encode(leafType) }
          }
        }
      } else {
        encoder.encodeProperty(name: "oneOf") { encoder in
          encoder.encodeArray { encoder in
            /// Encode `"null"`
            encoder.encodeElement { encoder in
              encoder.encodeObject { encoder in
                encoder.encodeProperty(name: "type") { $0.encode("null") }
              }
            }

            /// Encode wrapped schema
            encoder.encodeElement { stream in
              if wrappedSchema.mayAcceptNullValue {
                /// If the wrapped schema may accept a null value, we use a non-nullable wrappper object to encode it.
                stream.encodeObject { encoder in
                  /// This is implied by `properties`
                  // encoder.encodeProperty(name: "type") { $0.encode("object") }
                  encoder.encodeProperty(name: "properties") { encoder in
                    encoder.encodeObject { encoder in
                      encoder.encodeProperty(name: "value") { stream in
                        stream.encodeSchemaDefinition(wrappedSchema)
                      }
                    }
                  }
                }
              } else {
                /// If the wrapped schema does not accept null, we can encode it directly
                stream.encodeSchemaDefinition(wrappedSchema)
              }
            }
          }
        }
      }
    }

  }

  enum ValueDecodingState {
    case decodingNonNullableWrapperPrologue(JSON.ObjectDecodingState)
    case decodingValue(WrappedSchema.ValueDecodingState, JSON.ObjectDecodingState?)
    case decodingNonNullableWrapperEpilogue(Value, JSON.ObjectDecodingState)
    case decodingValueOrNull
  }
  var initialValueDecodingState: ValueDecodingState {
    if wrappedSchema.mayAcceptNullValue {
      /// We are using the non-nullable wrapper
      .decodingNonNullableWrapperPrologue(JSON.ObjectDecodingState())
    } else {
      .decodingValueOrNull
    }
  }

  func decodeValue(
    from stream: inout JSON.DecodingStream,
    state: inout ValueDecodingState
  ) throws -> JSON.DecodingResult<WrappedSchema.Value?> {
    while true {
      switch state {
      case .decodingNonNullableWrapperPrologue(var objectState):
        let header = try stream.decodeObjectComponent(&objectState)
        switch header {
        case .needsMoreData:
          state = .decodingNonNullableWrapperPrologue(objectState)
          return .needsMoreData
        case .decoded(.propertyValueStart(let name)):
          if name == "value" {
            state = .decodingValue(wrappedSchema.initialValueDecodingState, objectState)
          } else {
            /// Ignore properties
            objectState.ignorePropertyValue()
            state = .decodingNonNullableWrapperPrologue(objectState)
          }
        case .decoded(.end):
          return .decoded(nil)
        }
      case .decodingValueOrNull:
        switch try stream.decodeNullIfPresent() {
        case .needsMoreData:
          return .needsMoreData
        case .decoded(let isNull):
          if isNull {
            return .decoded(nil)
          } else {
            state = .decodingValue(wrappedSchema.initialValueDecodingState, nil)
          }
        }
      case .decodingValue(var valueState, let objectState):
        switch try wrappedSchema.decodeValue(from: &stream, state: &valueState) {
        case .needsMoreData:
          state = .decodingValue(valueState, objectState)
          return .needsMoreData
        case .decoded(let value):
          if let objectState {
            state = .decodingNonNullableWrapperEpilogue(value, objectState)
          } else {
            return .decoded(value)
          }
        }
      case .decodingNonNullableWrapperEpilogue(let value, var objectState):
        switch try stream.decodeObjectUntilComplete(&objectState) {
        case .needsMoreData:
          return .needsMoreData
        case .decoded(()):
          return .decoded(value)
        }
      }
    }
  }

  var valueWhenOmitted: Value { nil }

  func shouldOmit(_ value: Value) -> Bool {
    value == nil
  }

  func encodeWrappedSchemaDefinition(
    to stream: inout JSON.EncodingStream,
    descriptionPrefix: String?,
    descriptionSuffix: String?
  ) {
    stream.encodeSchemaDefinition(
      wrappedSchema,
      descriptionPrefix: descriptionPrefix,
      descriptionSuffix: descriptionSuffix
    )
  }

  var mayAcceptNullValue: Bool {
    true
  }

  func encode(_ value: Value, to stream: inout JSON.EncodingStream) {
    if let value = value {
      wrappedSchema.encode(value, to: &stream)
    } else {
      stream.encodeNull()
    }
  }

}

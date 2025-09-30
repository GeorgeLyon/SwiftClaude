import JSONSupport

// MARK: - API

extension SchemaCoding.Support {

  public static func schema<Value: SchemaCodable>(
    representing value: Value?.Type,
    description: String? = nil
  ) -> OptionalSchema<Value.Schema> {
    OptionalSchema(
      description: description,
      wrappedSchema: Value.schema
    )
  }

}

// MARK: - Schema Codable Conformance

extension Optional: SchemaCoding.SchemaCodable where Wrapped: SchemaCoding.SchemaCodable {

  public static var schema: SchemaCoding.Support.OptionalSchema<Wrapped.Schema> {
    SchemaCoding.Support.OptionalSchema(
      description: nil,
      wrappedSchema: Wrapped.schema
    )
  }

}

// MARK: - Schema

extension SchemaCoding.Support {

  public struct OptionalSchema<WrappedSchema: SchemaCoding.Schema>: Schema {

    public typealias Value = WrappedSchema.Value?

    public func encode(
      _ value: WrappedSchema.Value?,
      to encoder: inout Encoder
    ) {
      if wrappedSchema.schemaMetadata.mayAcceptNull {
        /// If the wrapped schema accepts `null`, we cannot represent `.none` as `null`.
        /// Instead we represent the optional as an object, where the presence or absence of the `value` property indicates `.none` or `.some(value)` respectively.
        encoder.stream.encodeObject { objectEncoder in
          if let value {
            objectEncoder.encodeProperty(name: nonNullableWrapperPropertyName) { stream in
              stream.encode(value, using: wrappedSchema)
            }
          }
        }
      } else {
        /// We can encode the `.none` case as `null`, and `.some` case directly
        if let value {
          wrappedSchema.encode(value, to: &encoder)
        } else {
          encoder.stream.encodeNull()
        }
      }
    }

    public struct ValueDecodingState: Sendable {
      fileprivate var objectState = JSON.ObjectDecodingState()
      fileprivate var phase: OptionalSchemaDecodingPhase<Value>

      fileprivate var wrappedState: WrappedSchema.ValueDecodingState
    }

    public var initialValueDecodingState: ValueDecodingState {
      ValueDecodingState(
        phase: wrappedSchema.schemaMetadata.mayAcceptNull
          ? .decodingObject(decodedValue: nil) : .decodingWrappedValue(canBeNull: true),
        wrappedState: wrappedSchema.initialValueDecodingState
      )
    }

    public func decodeValue(
      from decoder: inout Decoder,
      state: inout ValueDecodingState
    ) throws -> DecodingResult<Value> {
      while true {
        switch state.phase {
        case .decodingObject(let decodedValue):
          switch try decoder.stream.decodeObjectComponent(state: &state.objectState) {
          case .incomplete:
            return .incomplete
          case .decoded(.propertyValueStart(let name)):
            guard decodedValue == nil else {
              throw Error.multiplePropertiesWithSameName(String(name))
            }
            guard name == nonNullableWrapperPropertyName else {
              throw Error.unknownPropertyName(String(name))
            }
            state.phase = .decodingWrappedValue(canBeNull: false)
          case .decoded(.end):
            return .decoded(decodedValue)
          }
        case .decodingWrappedValue(let canBeNull):
          if canBeNull {
            switch try decoder.stream.peekValueKind() {
            case .incomplete:
              return .incomplete

            case .decoded(let kind):
              switch kind {
              case .null:
                return try decoder.stream.decodeNull()
                  .map { _ in nil }
                  .schemaDecodingResult
              case .boolean, .number, .string, .array, .object:
                state.phase = .decodingWrappedValue(canBeNull: false)
              }
            }
          }

          switch try wrappedSchema.decodeValue(from: &decoder, state: &state.wrappedState).kind {
          case .incomplete:
            return .incomplete
          case .decoded(let value):
            if wrappedSchema.schemaMetadata.mayAcceptNull {
              state.phase = .decodingObject(decodedValue: value)
            } else {
              return .decoded(value)
            }
          }
        }
      }
    }

    public var schemaMetadata: SchemaCoding.Support.SchemaMetadata {
      SchemaCoding.Support.SchemaMetadata(
        primitiveRepresentation: nil,
        mayAcceptNull: true
      )
    }

    #if ENABLE_META_SCHEMA
      @SchemaBuilder
      public func metaSchema(in context: SchemaContext) -> some SchemaCoding.Schema<Self> {
        let descriptionProperty =
          objectProperty(
            name: SchemaCodingKey.description,
            constantValue: context.contextualDescription(for: description)
          )
        if wrappedSchema.schemaMetadata.mayAcceptNull {
          let schema = objectSchema {
            descriptionProperty
            objectProperty(
              name: SchemaCodingKey.properties,
              schema: objectSchema {
                objectProperty(
                  name: SchemaCodingKey.value,
                  schema: wrappedSchema.metaSchema
                )
              }
            )
          }
          schema.wrap { (wrapped: (()?, WrappedSchema)) in
            OptionalSchema(description: description, wrappedSchema: wrapped.1)
          } unwrap: { (wrapper: Self) in
            ((), wrapper.wrappedSchema)
          }
        } else if let primitiveRepresentation = wrappedSchema.schemaMetadata.primitiveRepresentation
        {
          let schema = objectSchema {
            descriptionProperty
            objectProperty(
              name: SchemaCodingKey.type,
              constantValue: ["null", primitiveRepresentation]
            )
          }
          schema.wrap { (wrapped: (()?, ())) in
            OptionalSchema(description: description, wrappedSchema: wrappedSchema)
          } unwrap: { (wrapper: Self) in
            ((), ())
          }
        } else {
          let schema = objectSchema {
            descriptionProperty
            objectProperty(
              name: SchemaCodingKey.oneOf,
              schema: tupleSchema {
                nullSchema
                wrappedSchema.metaSchema
              }
            )
          }
          schema.wrap { (wrapped: (()?, ((), WrappedSchema))) in
            OptionalSchema(
              description: description,
              wrappedSchema: wrapped.1.1
            )
          } unwrap: { (wrapper: Self) in
            ((), ((), wrapper.wrappedSchema))
          }
        }
      }
    #endif

    let description: String?
    let wrappedSchema: WrappedSchema

    fileprivate init(
      description: String? = nil,
      wrappedSchema: WrappedSchema
    ) {
      self.description = description
      self.wrappedSchema = wrappedSchema
    }

  }

  fileprivate enum OptionalSchemaDecodingPhase<Value: Sendable> {
    case decodingObject(decodedValue: Value)
    case decodingWrappedValue(canBeNull: Bool)
  }

}

// MARK: - Coding Keys

private let nonNullableWrapperPropertyName = "value"

private enum SchemaCodingKey: CodingKey {
  case properties, type, description, value, oneOf
}

// MARK: - Errors

private enum Error: Swift.Error {
  case unknownPropertyName(String)
  case multiplePropertiesWithSameName(String)
}

import SchemaCoding
import SchemaCodingTestSupport
import Testing

@Suite("Enum")
struct EnumSchemaTests {

  @Test
  func manualStandardSchemaTest() throws {
    enum TestEnum: SchemaCoding.SchemaCodable, Equatable {
      case first
      case second(Int)
      case third(a: String, b: Bool)
      case fourth(String, Bool)

      static var schema: some SchemaCoding.Schema<Self> {
        let firstCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.first,
          associatedValues: {

          },
          finishDecoding: {
            Self.first
          }
        )
        let secondCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.second,
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { values in
            Self.second(values)
          }
        )
        let thirdCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.third,
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: ThirdCaseLabel.a,
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: ThirdCaseLabel.b,
              schema: SchemaCoding.Support.schema(representing: Bool.self)
            )
          },
          finishDecoding: { value1, value2 in
            Self.third(a: value1, b: value2)
          }
        )
        let fourthCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.fourth,
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Bool.self)
            )
          },
          finishDecoding: { value0, value1 in
            Self.fourth(value0, value1)
          }
        )
        return SchemaCoding.Support.enumSchema(
          cases: {
            firstCase
            secondCase
            thirdCase
            fourthCase
          },
          encodeValue: { value, encoder in
            let encodings = encoder.encodings
            switch value {
            case .first:
              let encoding = encodings.0
              encoder.encode((), using: encoding)
            case .second(let intValue):
              let encoding = encodings.1
              encoder.encode((intValue), using: encoding)
            case .third(let a, let b):
              let encoding = encodings.2
              encoder.encode((a, b), using: encoding)
            case .fourth(let stringValue, let boolValue):
              let encoding = encodings.3
              encoder.encode((stringValue, boolValue), using: encoding)
            }
          }
        )
      }

      private enum CaseName: CodingKey {
        case first, second, third, fourth
      }
      private enum ThirdCaseLabel: CodingKey {
        case a, b
      }

    }

    try test(
      TestEnum.first,
      isCodedAs: #"{"first":{}}"#
    )
    try test(
      TestEnum.second(42),
      isCodedAs: #"{"second":42}"#
    )
    try test(
      TestEnum.third(a: "Hello", b: true),
      isCodedAs: #"{"third":{"a":"Hello","b":true}}"#
    )
    try test(
      TestEnum.fourth("World", false),
      isCodedAs: #"{"fourth":["World",false]}"#
    )
  }

  @Test
  func manualInternallyTaggedSchemaTest() throws {
    enum TestEnum: SchemaCoding.SchemaCodable, Equatable {
      case first
      case second(a: Int)
      case third(b: String, c: Bool)

      struct Fourth: SchemaCoding.SchemaCodable, Equatable {
        let x: String
        let y: Int

        private enum CodingKeys: String, CodingKey {
          case x, y
        }
        static var schema: some SchemaCoding.ObjectSchema<Self> {
          SchemaCoding.Support.structSchema(
            description: "Fourth",
            propertyName: CodingKeys.self,
            properties: {
              SchemaCoding.Support.structProperty(
                name: CodingKeys.x,
                schema: SchemaCoding.Support.schema(representing: String.self),
                keyPath: \Self.x
              )
              SchemaCoding.Support.structProperty(
                name: CodingKeys.y,
                schema: SchemaCoding.Support.schema(representing: Int.self),
                keyPath: \Self.y
              )
            },
            finishDecoding: { decoder in
              let values = decoder.propertyValues
              return Self(
                x: values.0,
                y: values.1
              )
            }
          )
        }
      }
      case fourth(Fourth)

      private enum CaseName: CodingKey {
        case first, second, third, fourth
      }
      private enum SecondCaseLabel: CodingKey {
        case a
      }
      private enum ThirdCaseLabel: CodingKey {
        case b, c
      }

      static var schema: some SchemaCoding.Schema<Self> {
        let firstCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.first,
          associatedValues: {},
          finishDecoding: { Self.first }
        )
        let secondCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.second,
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: SecondCaseLabel.a,
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { value in
            Self.second(a: value)
          }
        )
        let thirdCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.third,
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: ThirdCaseLabel.b,
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: ThirdCaseLabel.c,
              schema: SchemaCoding.Support.schema(representing: Bool.self)
            )
          },
          finishDecoding: { value1, value2 in
            Self.third(b: value1, c: value2)
          }
        )
        let fourthCase = SchemaCoding.Support.enumSchemaCase(
          name: CaseName.fourth,
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: Fourth.schema
            )
          },
          finishDecoding: { value in
            Self.fourth(value)
          }
        )
        return SchemaCoding.Support.enumSchema(
          style: .internallyTagged(discriminatorPropertyName: "type"),
          cases: {
            firstCase
            secondCase
            thirdCase
            fourthCase
          },
          encodeValue: { value, encoder in
            let encodings = encoder.encodings
            switch value {
            case .first:
              let encoding = encodings.0
              encoder.encode((), using: encoding)
            case .second(let intValue):
              let encoding = encodings.1
              encoder.encode((intValue), using: encoding)
            case .third(let stringValue, let boolValue):
              let encoding = encodings.2
              encoder.encode((stringValue, boolValue), using: encoding)
            case .fourth(let fourth):
              let encoding = encodings.3
              encoder.encode(fourth, using: encoding)
            }
          }
        )
      }
    }

    try test(
      TestEnum.first,
      isCodedAs: #"{"type":"first"}"#
    )
    try test(
      TestEnum.second(a: 42),
      isCodedAs: #"{"type":"second","a":42}"#
    )
    try test(
      TestEnum.third(b: "Hello", c: true),
      isCodedAs: #"{"type":"third","b":"Hello","c":true}"#
    )
    try test(
      TestEnum.fourth(.init(x: "World", y: 100)),
      isCodedAs: #"{"type":"fourth","x":"World","y":100}"#
    )
  }

  @SchemaCodable(
    description: "Standard Test Enum"
  )
  enum StandardTestEnum: Equatable {
    @SchemaDetails(
      description: "First case with no associated values"
    )
    case first

    case second(Int)
    case third(a: String, b: Bool)
    case fourth(String, Bool)
  }

  @Test
  func standardSchemaTest() throws {
    try test(
      StandardTestEnum.first,
      isCodedAs: #"{"first":{}}"#
    )
    try test(
      StandardTestEnum.second(42),
      isCodedAs: #"{"second":42}"#
    )
    try test(
      StandardTestEnum.third(a: "Hello", b: true),
      isCodedAs: #"{"third":{"a":"Hello","b":true}}"#
    )
    try test(
      StandardTestEnum.fourth("World", false),
      isCodedAs: #"{"fourth":["World",false]}"#
    )
  }

  #if false
    @Test
    func testStandardEnumSchema() throws {
      try StandardTestEnum.schema.test(
        encodesAs: """
          {
            "description": "Standard Test Enum",
            "maxProperties": 1,
            "properties": {
              "first": {
                "description": "First case with no associated values",
                "properties": {

                }
              },
              "second": {
                "type": "integer"
              },
              "third": {
                "properties": {
                  "a": {
                    "type": "string"
                  },
                  "b": {
                    "type": "boolean"
                  }
                },
                "required": [
                  "a",
                  "b"
                ]
              },
              "fourth": {
                "prefixItems": [
                  {
                    "type": "string"
                  },
                  {
                    "type": "boolean"
                  }
                ]
              }
            }
          }
          """,
        prettyPrint: true
      )
    }
  #endif

  @SchemaCodable(
    style: .internallyTagged(
      discriminatorPropertyName: "type"
    )
  )
  enum InternallyTaggedTestEnum: Equatable {
    case first(a: Int, b: String)
    case second(x: Int)
    @SchemaCodable
    struct Third: Equatable {
      let baz: String
    }
    case third(Third)
    case fourth
  }

  @Test
  func internallyTaggedSchemaTest() throws {
    try test(
      InternallyTaggedTestEnum.first(a: 1, b: "2"),
      isCodedAs: #"{"type":"first","a":1,"b":"2"}"#
    )
    try test(
      InternallyTaggedTestEnum.second(x: 10),
      isCodedAs: #"{"type":"second","x":10}"#
    )
    try test(
      InternallyTaggedTestEnum.third(.init(baz: "BAZ!")),
      isCodedAs: #"{"type":"third","baz":"BAZ!"}"#
    )
    try test(
      InternallyTaggedTestEnum.fourth,
      isCodedAs: #"{"type":"fourth"}"#
    )
  }

  /// Omninously, this test crashes with what seems like a double-release when exiting the function scope
  #if false
    @Test
    func testInternallyTaggedEnumSchema() throws {
      try InternallyTaggedTestEnum.schema.test(
        encodesAs: """
          {
            "oneOf": [
              {
                "properties": {
                  "type": {
                    "const": "first"
                  },
                  "a": {
                    "type": "integer"
                  },
                  "b": {
                    "type": "string"
                  }
                }
              },
              {
                "properties": {
                  "type": {
                    "const": "second"
                  },
                  "x": {
                    "type": "integer"
                  }
                }
              },
              {
                "properties": {
                  "type": {
                    "const": "third"
                  },
                  "baz": {
                    "type": "string"
                  }
                }
              },
              {
                "properties": {
                  "type": {
                    "const": "fourth"
                  }
                }
              }
            ]
          }
          """,
        prettyPrint: true
      )
    }
  #endif

}

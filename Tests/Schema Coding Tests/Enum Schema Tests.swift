import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Enum Schema")
struct EnumSchemaTests {

  // MARK: - Test Enums

  enum SimpleEnum: Equatable {
    case first
    case second
  }

  enum SingleValueEnum: Equatable {
    case value(Int)
  }

  enum LabeledValuesEnum: Equatable {
    case point(x: Int, y: Int)
  }

  enum TupleValuesEnum: Equatable {
    case pair(String, Bool)
  }

  enum MixedEnum: Equatable {
    case empty
    case single(Int)
    case labeled(name: String, age: Int)
    case tuple(String, Bool)
  }

  // MARK: - Encoding Tests

  @Suite("Encoding")
  struct EncodingTests {

    @Test
    func encodeSimpleCase() throws {
      let schema = SchemaCoding.Support.enumSchema(representing: SimpleEnum.self) {
        SchemaCoding.Support.enumSchemaCase(
          name: "first",
          associatedValues: {},
          finishDecoding: { SimpleEnum.first }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "second",
          associatedValues: {},
          finishDecoding: { SimpleEnum.second }
        )
      } encodeValue: { value, encoder in
        switch value {
        case .first:
          encoder.encode((), using: encoder.encodings.0)
        case .second:
          encoder.encode((), using: encoder.encodings.1)
        }
      }

      try schema.test(SimpleEnum.first, isCodedAs: #"{"first":{}}"#)
      try schema.test(SimpleEnum.second, isCodedAs: #"{"second":{}}"#)
    }

    @Test
    func encodeMixedEnum() throws {
      let schema = SchemaCoding.Support.enumSchema(representing: MixedEnum.self) {
        SchemaCoding.Support.enumSchemaCase(
          name: "empty",
          associatedValues: {},
          finishDecoding: { MixedEnum.empty }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "single",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { intValue in
            MixedEnum.single(intValue)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "labeled",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "name",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "age",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { decoder in
            let values = decoder.associatedValues
            return MixedEnum.labeled(name: values.0, age: values.1)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "tuple",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Bool.self)
            )
          },
          finishDecoding: { decoder in
            let values = decoder.associatedValues
            return MixedEnum.tuple(values.0, values.1)
          }
        )
      } encodeValue: { value, encoder in
        let encodings = encoder.encodings
        switch value {
        case .empty:
          encoder.encode((), using: encodings.0)
        case .single(let intValue):
          encoder.encode(intValue, using: encodings.1)
        case .labeled(let name, let age):
          encoder.encode((name, age), using: encodings.2)
        case .tuple(let str, let bool):
          encoder.encode((str, bool), using: encodings.3)
        }
      }

      try schema.test(MixedEnum.empty, isCodedAs: #"{"empty":{}}"#)
      try schema.test(MixedEnum.single(42), isCodedAs: #"{"single":42}"#)
      try schema.test(
        MixedEnum.labeled(name: "Alice", age: 30),
        isCodedAs: #"{"labeled":{"name":"Alice","age":30}}"#
      )
      try schema.test(
        MixedEnum.tuple("test", true),
        isCodedAs: #"{"tuple":["test",true]}"#
      )
    }

  }
  /*
    // MARK: - Decoding Tests
  
    @Suite("Decoding")
    struct DecodingTests {
  
      @Test
      func decodeSimpleCase() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: SimpleEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "first",
            associatedValues: {},
            finishDecoding: { SimpleEnum.first }
          )
          SchemaCoding.Support.enumSchemaCase(
            name: "second",
            associatedValues: {},
            finishDecoding: { SimpleEnum.second }
          )
        } encodeValue: { value, encoder in
          let encodings = encoder.encodings
          switch value {
          case .first:
            encoder.encode((), using: encodings.0)
          case .second:
            encoder.encode((), using: encodings.1)
          }
        }
  
        try schema.test(#"{"first":{}}"#, decodesAs: SimpleEnum.first)
        try schema.test(#"{"second":{}}"#, decodesAs: SimpleEnum.second)
      }
  
      @Test
      func decodeSingleAssociatedValue() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: SingleValueEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "value",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
            },
            finishDecoding: { intValue in
              SingleValueEnum.value(intValue)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .value(let intValue):
            encoder.encode(intValue, using: encoder.encodings)
          }
        }
  
        try schema.test(#"{"value":42}"#, decodesAs: SingleValueEnum.value(42))
        try schema.test(#"{"value":-10}"#, decodesAs: SingleValueEnum.value(-10))
        try schema.test(#"{"value":0}"#, decodesAs: SingleValueEnum.value(0))
      }
  
      @Test
      func decodeLabeledAssociatedValues() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: LabeledValuesEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "point",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "x",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "y",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
            },
            finishDecoding: { decoder in
              let values = decoder.associatedValues
              return LabeledValuesEnum.point(x: values.0, y: values.1)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .point(let x, let y):
            encoder.encode((x, y), using: encoder.encodings)
          }
        }
  
        try schema.test(
          #"{"point":{"x":10,"y":20}}"#,
          decodesAs: LabeledValuesEnum.point(x: 10, y: 20)
        )
      }
  
      @Test
      func decodeLabeledValuesInDifferentOrder() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: LabeledValuesEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "point",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "x",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "y",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
            },
            finishDecoding: { decoder in
              let values = decoder.associatedValues
              return LabeledValuesEnum.point(x: values.0, y: values.1)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .point(let x, let y):
            encoder.encode((x, y), using: encoder.encodings)
          }
        }
  
        try schema.test(
          #"{"point":{"y":20,"x":10}}"#,
          decodesAs: LabeledValuesEnum.point(x: 10, y: 20)
        )
      }
  
      @Test
      func decodeTupleAssociatedValues() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: TupleValuesEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "pair",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: String.self)
              )
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: Bool.self)
              )
            },
            finishDecoding: { decoder in
              let values = decoder.associatedValues
              return TupleValuesEnum.pair(values.0, values.1)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .pair(let str, let bool):
            encoder.encode((str, bool), using: encoder.encodings)
          }
        }
  
        try schema.test(
          #"{"pair":["hello",true]}"#,
          decodesAs: TupleValuesEnum.pair("hello", true)
        )
        try schema.test(
          #"{"pair":["world",false]}"#,
          decodesAs: TupleValuesEnum.pair("world", false)
        )
      }
  
      @Test
      func decodeWithWhitespace() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: SimpleEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "first",
            associatedValues: {},
            finishDecoding: { SimpleEnum.first }
          )
          SchemaCoding.Support.enumSchemaCase(
            name: "second",
            associatedValues: {},
            finishDecoding: { SimpleEnum.second }
          )
        } encodeValue: { value, encoder in
          let encodings = encoder.encodings
          switch value {
          case .first:
            encoder.encode((), using: encodings.0)
          case .second:
            encoder.encode((), using: encodings.1)
          }
        }
  
        try schema.test("{ \"first\" : { } }", decodesAs: SimpleEnum.first)
      }
  
    }
  
    // MARK: - Chunked Decoding Tests
  
    @Suite("Chunked Decoding")
    struct ChunkedDecodingTests {
  
      @Test
      func chunkedSimpleEnumDecoding() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: SimpleEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "first",
            associatedValues: {},
            finishDecoding: { SimpleEnum.first }
          )
          SchemaCoding.Support.enumSchemaCase(
            name: "second",
            associatedValues: {},
            finishDecoding: { SimpleEnum.second }
          )
        } encodeValue: { value, encoder in
          let encodings = encoder.encodings
          switch value {
          case .first:
            encoder.encode((), using: encodings.0)
          case .second:
            encoder.encode((), using: encodings.1)
          }
        }
  
        try schema.test(["{", "\"first\"", ":", "{}", "}"], decodesAs: SimpleEnum.first)
      }
  
      @Test
      func chunkedSingleValueDecoding() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: SingleValueEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "value",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
            },
            finishDecoding: { intValue in
              SingleValueEnum.value(intValue)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .value(let intValue):
            encoder.encode(intValue, using: encoder.encodings)
          }
        }
  
        try schema.test(["{", "\"value\"", ":", "42", "}"], decodesAs: SingleValueEnum.value(42))
      }
  
      @Test
      func chunkedLabeledValuesDecoding() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: LabeledValuesEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "point",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "x",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "y",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
            },
            finishDecoding: { decoder in
              let values = decoder.associatedValues
              return LabeledValuesEnum.point(x: values.0, y: values.1)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .point(let x, let y):
            encoder.encode((x, y), using: encoder.encodings)
          }
        }
  
        try schema.test(
          ["{", "\"point\"", ":", "{", "\"x\"", ":", "10", ",", "\"y\"", ":", "20", "}", "}"],
          decodesAs: LabeledValuesEnum.point(x: 10, y: 20)
        )
      }
  
      @Test
      func chunkedTupleValuesDecoding() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: TupleValuesEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "pair",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: String.self)
              )
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: Bool.self)
              )
            },
            finishDecoding: { decoder in
              let values = decoder.associatedValues
              return TupleValuesEnum.pair(values.0, values.1)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .pair(let str, let bool):
            encoder.encode((str, bool), using: encoder.encodings)
          }
        }
  
        try schema.test(
          ["{", "\"pair\"", ":", "[", "\"hello\"", ",", "true", "]", "}"],
          decodesAs: TupleValuesEnum.pair("hello", true)
        )
      }
  
    }
  
    // MARK: - Meta Schema Tests
  
    @Suite("Meta Schema")
    struct MetaSchemaTests {
  
      @Test
      func simpleEnumMetaSchema() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: SimpleEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "first",
            associatedValues: {},
            finishDecoding: { SimpleEnum.first }
          )
          SchemaCoding.Support.enumSchemaCase(
            name: "second",
            associatedValues: {},
            finishDecoding: { SimpleEnum.second }
          )
        } encodeValue: { value, encoder in
          let encodings = encoder.encodings
          switch value {
          case .first:
            encoder.encode((), using: encodings.0)
          case .second:
            encoder.encode((), using: encodings.1)
          }
        }
  
        try schema.test(
          encodesAs: """
            {
              "properties": {
                "first": {
                  "properties": {
  
                  }
                },
                "second": {
                  "properties": {
  
                  }
                }
              }
            }
            """,
          prettyPrint: true
        )
      }
  
      @Test
      func singleValueEnumMetaSchema() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: SingleValueEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "value",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
            },
            finishDecoding: { intValue in
              SingleValueEnum.value(intValue)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .value(let intValue):
            encoder.encode(intValue, using: encoder.encodings)
          }
        }
  
        try schema.test(
          encodesAs: """
            {
              "properties": {
                "value": {
                  "type": "integer"
                }
              }
            }
            """,
          prettyPrint: true
        )
      }
  
      @Test
      func labeledValuesEnumMetaSchema() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: LabeledValuesEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "point",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "x",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                label: "y",
                schema: SchemaCoding.Support.schema(representing: Int.self)
              )
            },
            finishDecoding: { decoder in
              let values = decoder.associatedValues
              return LabeledValuesEnum.point(x: values.0, y: values.1)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .point(let x, let y):
            encoder.encode((x, y), using: encoder.encodings)
          }
        }
  
        try schema.test(
          encodesAs: """
            {
              "properties": {
                "point": {
                  "properties": {
                    "x": {
                      "type": "integer"
                    },
                    "y": {
                      "type": "integer"
                    }
                  },
                  "required": [
                    "x",
                    "y"
                  ]
                }
              }
            }
            """,
          prettyPrint: true
        )
      }
  
      @Test
      func tupleValuesEnumMetaSchema() throws {
        let schema = SchemaCoding.Support.enumSchema(representing: TupleValuesEnum.self) {
          SchemaCoding.Support.enumSchemaCase(
            name: "pair",
            associatedValues: {
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: String.self)
              )
              SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                schema: SchemaCoding.Support.schema(representing: Bool.self)
              )
            },
            finishDecoding: { decoder in
              let values = decoder.associatedValues
              return TupleValuesEnum.pair(values.0, values.1)
            }
          )
        } encodeValue: { value, encoder in
          switch value {
          case .pair(let str, let bool):
            encoder.encode((str, bool), using: encoder.encodings)
          }
        }
  
        try schema.test(
          encodesAs: """
            {
              "properties": {
                "pair": {
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
  
    }
  */
}

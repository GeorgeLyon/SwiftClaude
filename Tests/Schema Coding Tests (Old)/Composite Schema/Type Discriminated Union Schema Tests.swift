import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Type Discriminated Union Schema")
struct TypeDiscriminatedUnionSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testStringOnlyUnion() throws {
      enum StringOrNothing: Equatable {
        case string(String)
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: StringOrNothing.self,
        null: .never(),
        boolean: .never(),
        number: .never(),
        string: .init(
          schema: SchemaCoding.Support.StringSchema(),
          finishDecoding: { StringOrNothing.string($0) }
        ),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .string(let s):
            encoder.encode(s, using: encoder.stringEncoding)
          }
        }
      )

      try schema.test(
        StringOrNothing.string("hello"),
        isCodedAs: #""hello""#
      )
    }

    @Test
    func testBooleanOnlyUnion() throws {
      enum BooleanOrNothing: Equatable {
        case boolean(Bool)
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: BooleanOrNothing.self,
        null: .never(),
        boolean: .init(
          schema: SchemaCoding.Support.BooleanSchema(),
          finishDecoding: { BooleanOrNothing.boolean($0) }
        ),
        number: .never(),
        string: .never(),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .boolean(let b):
            encoder.encode(b, using: encoder.booleanEncoding)
          }
        }
      )

      try schema.test(
        BooleanOrNothing.boolean(true),
        isCodedAs: "true"
      )
      try schema.test(
        BooleanOrNothing.boolean(false),
        isCodedAs: "false"
      )
    }

    @Test
    func testNumberOnlyUnion() throws {
      enum NumberOrNothing: Equatable {
        case number(Int)
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: NumberOrNothing.self,
        null: .never(),
        boolean: .never(),
        number: .init(
          schema: SchemaCoding.Support.schema(representing: Int.self),
          finishDecoding: { NumberOrNothing.number($0) }
        ),
        string: .never(),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .number(let n):
            encoder.encode(n, using: encoder.numberEncoding)
          }
        }
      )

      try schema.test(
        NumberOrNothing.number(42),
        isCodedAs: "42"
      )
      try schema.test(
        NumberOrNothing.number(-123),
        isCodedAs: "-123"
      )
    }

    @Test
    func testNullOnlyUnion() throws {
      enum NullOrNothing: Equatable {
        case null
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: NullOrNothing.self,
        null: .init(
          schema: SchemaCoding.Support.NullSchema(),
          finishDecoding: { NullOrNothing.null }
        ),
        boolean: .never(),
        number: .never(),
        string: .never(),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .null:
            encoder.encode((), using: encoder.nullEncoding)
          }
        }
      )

      try schema.test(
        NullOrNothing.null,
        isCodedAs: "null"
      )
    }

    @Test
    func testArrayOnlyUnion() throws {
      enum ArrayOrNothing: Equatable {
        case array([Int])
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: ArrayOrNothing.self,
        null: .never(),
        boolean: .never(),
        number: .never(),
        string: .never(),
        array: .init(
          schema: SchemaCoding.Support.ArraySchema(
            elementSchema: SchemaCoding.Support.schema(representing: Int.self)
          ),
          finishDecoding: { ArrayOrNothing.array($0) }
        ),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .array(let arr):
            encoder.encode(arr, using: encoder.arrayEncoding)
          }
        }
      )

      try schema.test(
        ArrayOrNothing.array([1, 2, 3]),
        isCodedAs: """
          [
            1,
            2,
            3
          ]
          """
      )
      try schema.test(
        ArrayOrNothing.array([]),
        isCodedAs: """
          [

          ]
          """
      )
    }

    @Test
    func testObjectOnlyUnion() throws {
      enum ObjectOrNothing: Equatable {
        case object(x: Int, y: Int)
      }

      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "x",
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
        SchemaCoding.Support.DirectObjectProperty(
          name: "y",
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: ObjectOrNothing.self,
        null: .never(),
        boolean: .never(),
        number: .never(),
        string: .never(),
        array: .never(),
        object: .init(
          schema: objectSchema,
          finishDecoding: { ObjectOrNothing.object(x: $0.0, y: $0.1) }
        ),
        encodeValue: { value, encoder in
          switch value {
          case .object(let x, let y):
            encoder.encode((x, y), using: encoder.objectEncoding)
          }
        }
      )

      try schema.test(
        ObjectOrNothing.object(x: 10, y: 20),
        flatten: { value -> (Int, Int) in
          switch value {
          case .object(let x, let y):
            return (x, y)
          }
        },
        isCodedAs: """
          {
            "x": 10,
            "y": 20
          }
          """
      )
    }

    @Test
    func testBooleanOrStringUnion() throws {
      enum BoolOrString: Equatable {
        case boolean(Bool)
        case string(String)
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: BoolOrString.self,
        null: .never(),
        boolean: .init(
          schema: SchemaCoding.Support.BooleanSchema(),
          finishDecoding: { BoolOrString.boolean($0) }
        ),
        number: .never(),
        string: .init(
          schema: SchemaCoding.Support.StringSchema(),
          finishDecoding: { BoolOrString.string($0) }
        ),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .boolean(let b):
            encoder.encode(b, using: encoder.booleanEncoding)
          case .string(let s):
            encoder.encode(s, using: encoder.stringEncoding)
          }
        }
      )

      try schema.test(
        BoolOrString.boolean(true),
        isCodedAs: "true"
      )
      try schema.test(
        BoolOrString.boolean(false),
        isCodedAs: "false"
      )
      try schema.test(
        BoolOrString.string("hello"),
        isCodedAs: #""hello""#
      )
      try schema.test(
        BoolOrString.string(""),
        isCodedAs: #""""#
      )
    }

    @Test
    func testStringOrNumberOrNullUnion() throws {
      enum StringOrNumberOrNull: Equatable {
        case string(String)
        case number(Int)
        case null
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: StringOrNumberOrNull.self,
        null: .init(
          schema: SchemaCoding.Support.NullSchema(),
          finishDecoding: { StringOrNumberOrNull.null }
        ),
        boolean: .never(),
        number: .init(
          schema: SchemaCoding.Support.schema(representing: Int.self),
          finishDecoding: { StringOrNumberOrNull.number($0) }
        ),
        string: .init(
          schema: SchemaCoding.Support.StringSchema(),
          finishDecoding: { StringOrNumberOrNull.string($0) }
        ),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .string(let s):
            encoder.encode(s, using: encoder.stringEncoding)
          case .number(let n):
            encoder.encode(n, using: encoder.numberEncoding)
          case .null:
            encoder.encode((), using: encoder.nullEncoding)
          }
        }
      )

      try schema.test(
        StringOrNumberOrNull.string("test"),
        isCodedAs: #""test""#
      )
      try schema.test(
        StringOrNumberOrNull.number(99),
        isCodedAs: "99"
      )
      try schema.test(
        StringOrNumberOrNull.null,
        isCodedAs: "null"
      )
    }

    @Test
    func testAllTypesUnion() throws {
      enum JSONValue: Equatable {
        case null
        case boolean(Bool)
        case number(Int)
        case string(String)
        case array([Int])
        case object(name: String)
      }

      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "name",
          schema: SchemaCoding.Support.StringSchema()
        )
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: JSONValue.self,
        null: .init(
          schema: SchemaCoding.Support.NullSchema(),
          finishDecoding: { JSONValue.null }
        ),
        boolean: .init(
          schema: SchemaCoding.Support.BooleanSchema(),
          finishDecoding: { JSONValue.boolean($0) }
        ),
        number: .init(
          schema: SchemaCoding.Support.schema(representing: Int.self),
          finishDecoding: { JSONValue.number($0) }
        ),
        string: .init(
          schema: SchemaCoding.Support.StringSchema(),
          finishDecoding: { JSONValue.string($0) }
        ),
        array: .init(
          schema: SchemaCoding.Support.ArraySchema(
            elementSchema: SchemaCoding.Support.schema(representing: Int.self)
          ),
          finishDecoding: { JSONValue.array($0) }
        ),
        object: .init(
          schema: objectSchema,
          finishDecoding: { JSONValue.object(name: $0) }
        ),
        encodeValue: { value, encoder in
          switch value {
          case .null:
            encoder.encode((), using: encoder.nullEncoding)
          case .boolean(let b):
            encoder.encode(b, using: encoder.booleanEncoding)
          case .number(let n):
            encoder.encode(n, using: encoder.numberEncoding)
          case .string(let s):
            encoder.encode(s, using: encoder.stringEncoding)
          case .array(let arr):
            encoder.encode(arr, using: encoder.arrayEncoding)
          case .object(let name):
            encoder.encode(name, using: encoder.objectEncoding)
          }
        }
      )

      try schema.test(
        JSONValue.null,
        isCodedAs: "null"
      )
      try schema.test(
        JSONValue.boolean(true),
        isCodedAs: "true"
      )
      try schema.test(
        JSONValue.number(42),
        isCodedAs: "42"
      )
      try schema.test(
        JSONValue.string("hello"),
        isCodedAs: #""hello""#
      )
      try schema.test(
        JSONValue.array([1, 2]),
        isCodedAs: """
          [
            1,
            2
          ]
          """
      )
      try schema.test(
        JSONValue.object(name: "test"),
        isCodedAs: """
          {
            "name": "test"
          }
          """
      )
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testSingleCaseMetaSchema() throws {
      enum StringOnly: Equatable {
        case string(String)
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: StringOnly.self,
        null: .never(),
        boolean: .never(),
        number: .never(),
        string: .init(
          schema: SchemaCoding.Support.StringSchema(),
          finishDecoding: { StringOnly.string($0) }
        ),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .string(let s):
            encoder.encode(s, using: encoder.stringEncoding)
          }
        }
      )

      try schema.test(
        encodesAs: """
          {
            "oneOf": [
              {
                "type": "string"
              }
            ]
          }
          """
      )
    }

    @Test
    func testTwoCaseMetaSchema() throws {
      enum BoolOrString: Equatable {
        case boolean(Bool)
        case string(String)
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: BoolOrString.self,
        null: .never(),
        boolean: .init(
          schema: SchemaCoding.Support.BooleanSchema(),
          finishDecoding: { BoolOrString.boolean($0) }
        ),
        number: .never(),
        string: .init(
          schema: SchemaCoding.Support.StringSchema(),
          finishDecoding: { BoolOrString.string($0) }
        ),
        array: .never(),
        object: .never(),
        encodeValue: { value, encoder in
          switch value {
          case .boolean(let b):
            encoder.encode(b, using: encoder.booleanEncoding)
          case .string(let s):
            encoder.encode(s, using: encoder.stringEncoding)
          }
        }
      )

      try schema.test(
        encodesAs: """
          {
            "oneOf": [
              {
                "type": "boolean"
              },
              {
                "type": "string"
              }
            ]
          }
          """
      )
    }

    @Test
    func testAllCasesMetaSchema() throws {
      enum AllTypes: Equatable {
        case null
        case boolean(Bool)
        case number(Int)
        case string(String)
        case array([Int])
        case object(value: Int)
      }

      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "value",
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
      }

      let schema = SchemaCoding.Support.typeDiscriminatedUnionSchema(
        representing: AllTypes.self,
        null: .init(
          schema: SchemaCoding.Support.NullSchema(),
          finishDecoding: { AllTypes.null }
        ),
        boolean: .init(
          schema: SchemaCoding.Support.BooleanSchema(),
          finishDecoding: { AllTypes.boolean($0) }
        ),
        number: .init(
          schema: SchemaCoding.Support.schema(representing: Int.self),
          finishDecoding: { AllTypes.number($0) }
        ),
        string: .init(
          schema: SchemaCoding.Support.StringSchema(),
          finishDecoding: { AllTypes.string($0) }
        ),
        array: .init(
          schema: SchemaCoding.Support.ArraySchema(
            elementSchema: SchemaCoding.Support.schema(representing: Int.self)
          ),
          finishDecoding: { AllTypes.array($0) }
        ),
        object: .init(
          schema: objectSchema,
          finishDecoding: { AllTypes.object(value: $0) }
        ),
        encodeValue: { value, encoder in
          switch value {
          case .null:
            encoder.encode((), using: encoder.nullEncoding)
          case .boolean(let b):
            encoder.encode(b, using: encoder.booleanEncoding)
          case .number(let n):
            encoder.encode(n, using: encoder.numberEncoding)
          case .string(let s):
            encoder.encode(s, using: encoder.stringEncoding)
          case .array(let arr):
            encoder.encode(arr, using: encoder.arrayEncoding)
          case .object(let v):
            encoder.encode(v, using: encoder.objectEncoding)
          }
        }
      )

      try schema.test(
        encodesAs: """
          {
            "oneOf": [
              {
                "type": "null"
              },
              {
                "type": "boolean"
              },
              {
                "type": "integer"
              },
              {
                "type": "string"
              },
              {
                "items": {
                  "type": "integer"
                }
              },
              {
                "properties": {
                  "value": {
                    "type": "integer"
                  }
                },
                "required": [
                  "value"
                ]
              }
            ]
          }
          """
      )
    }

  }

}

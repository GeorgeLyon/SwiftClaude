import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Tuple Schema")
struct TupleSchemaTests {

  @Test
  func singleElementTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas: SchemaCoding.Support.StringSchema()
    )
    try schema.test(("hello"), isCodedAs: "[\"hello\"]")
    try schema.test(("world"), isCodedAs: "[\"world\"]")
    try schema.test((""), isCodedAs: "[\"\"]")
  }

  @Test
  func twoElementTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>()
    )
    try schema.test(("foo", 42), isCodedAs: "[\"foo\",42]")
    try schema.test(("bar", -10), isCodedAs: "[\"bar\",-10]")
    try schema.test(("", 0), isCodedAs: "[\"\",0]")
  }

  @Test
  func threeElementTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.BooleanSchema()
    )
    try schema.test(("test", 123, true), isCodedAs: "[\"test\",123,true]")
    try schema.test(("abc", -1, false), isCodedAs: "[\"abc\",-1,false]")
  }

  @Test
  func mixedTypesTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.DoubleSchema(),
      SchemaCoding.Support.BooleanSchema()
    )
    try schema.test(("test", 42, 3.14, true), isCodedAs: "[\"test\",42,3.14,true]")
    try schema.test(("", -1, -2.5, false), isCodedAs: "[\"\",-1,-2.5,false]")
  }

  @Test
  func homogeneousTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>()
    )
    try schema.test((1, 2, 3), isCodedAs: "[1,2,3]")
    try schema.test((42, 0, -17), isCodedAs: "[42,0,-17]")
    try schema.test((999, 999, 999), isCodedAs: "[999,999,999]")
  }

  @Test
  func largeTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.IntegerSchema<Int>()
    )
    try schema.test((1, 2, 3, 4, 5, 6, 7, 8), isCodedAs: "[1,2,3,4,5,6,7,8]")
    try schema.test((10, 20, 30, 40, 50, 60, 70, 80), isCodedAs: "[10,20,30,40,50,60,70,80]")
  }

  @Test
  func specialCharactersInStrings() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.StringSchema()
    )
    try schema.test(
      ("hello\nworld", "tab\there"),
      isCodedAs: "[\"hello\\nworld\",\"tab\\there\"]"
    )
    try schema.test(
      ("quote\"here", "backslash\\test"),
      isCodedAs: "[\"quote\\\"here\",\"backslash\\\\test\"]"
    )
    try schema.test(
      ("unicode: \u{1F44D}", "emoji: \u{1F389}"),
      isCodedAs: "[\"unicode: \u{1F44D}\",\"emoji: \u{1F389}\"]"
    )
  }

}

@Suite("Tuple Schema Decoding")
struct TupleSchemaDecodingTests {

  @Test
  func decodeTwoElementTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>()
    )
    try schema.test("[\"hello\",42]", decodesAs: ("hello", 42))
    try schema.test("[\"world\",-10]", decodesAs: ("world", -10))
  }

  @Test
  func decodeThreeElementTuple() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.BooleanSchema()
    )
    try schema.test("[\"test\",123,true]", decodesAs: ("test", 123, true))
    try schema.test("[\"abc\",-1,false]", decodesAs: ("abc", -1, false))
  }

  @Test
  func decodeWithWhitespace() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>()
    )
    try schema.test("[ \"hello\" , 42 ]", decodesAs: ("hello", 42))
    try schema.test("[\n  \"world\",\n  100\n]", decodesAs: ("world", 100))
  }

  @Test
  func chunkedDecoding() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>()
    )

    try schema.test(
      ["[", "\"hello\"", ",", "42", "]"],
      decodesAs: ("hello", 42)
    )

    try schema.test(
      ["[\"hel", "lo\",4", "2]"],
      decodesAs: ("hello", 42)
    )
  }

}

@Suite("Tuple Schema Nested")
struct TupleSchemaNestedTests {

  @Test
  func nestedTupleEncoding() throws {
    let innerSchema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.BooleanSchema()
    )
    let outerSchema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      innerSchema
    )

    var encoder = SchemaCoding.Support.Encoder()
    outerSchema.encode(("outer", (42, true)), to: &encoder)
    #expect(encoder.stream.stringRepresentation == "[\"outer\",[42,true]]")

    encoder = SchemaCoding.Support.Encoder()
    outerSchema.encode(("test", (0, false)), to: &encoder)
    #expect(encoder.stream.stringRepresentation == "[\"test\",[0,false]]")
  }

  @Test
  func tupleWithArray() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.IntegerSchema<Int>()
      )
    )

    var encoder = SchemaCoding.Support.Encoder()
    schema.encode(("items", [1, 2, 3]), to: &encoder)
    #expect(encoder.stream.stringRepresentation == "[\"items\",[1,2,3]]")
  }

}

@Suite("Tuple Schema Meta")
struct TupleSchemaMetaTests {

  @Test
  func twoElementMetaSchema() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>()
    )

    try schema.test(
      encodesAs: """
        {
          "prefixItems": [
            {
              "type": "string"
            },
            {
              "type": "integer"
            }
          ]
        }
        """,
      prettyPrint: true
    )
  }

  @Test
  func threeElementMetaSchema() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      elementSchemas:
        SchemaCoding.Support.StringSchema(),
      SchemaCoding.Support.IntegerSchema<Int>(),
      SchemaCoding.Support.BooleanSchema()
    )

    try schema.test(
      encodesAs: """
        {
          "prefixItems": [
            {
              "type": "string"
            },
            {
              "type": "integer"
            },
            {
              "type": "boolean"
            }
          ]
        }
        """,
      prettyPrint: true
    )
  }

  @Test
  func metaSchemaWithDescription() throws {
    let schema = SchemaCoding.Support.TupleSchema(
      description: "A coordinate pair",
      elementSchemas:
        SchemaCoding.Support.DoubleSchema(),
      SchemaCoding.Support.DoubleSchema()
    )

    try schema.test(
      encodesAs: """
        {
          "description": "A coordinate pair",
          "prefixItems": [
            {
              "type": "number"
            },
            {
              "type": "number"
            }
          ]
        }
        """,
      prettyPrint: true
    )
  }

}

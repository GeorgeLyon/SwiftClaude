import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Optional Schema")
struct OptionalSchemaTests {

  @Test
  func optionalStringWithValue() throws {
    let schema = String?.schema
    try schema.test("hello", isCodedAs: "{\"value\":\"hello\"}")
  }

  @Test
  func optionalStringWithNil() throws {
    let schema = String?.schema
    try schema.test(nil, isCodedAs: "{}")
  }

  @Test
  func optionalIntWithValue() throws {
    let schema = Int?.schema
    try schema.test(42, isCodedAs: "{\"value\":42}")
  }

  @Test
  func optionalIntWithNil() throws {
    let schema = Int?.schema
    try schema.test(nil, isCodedAs: "{}")
  }

  @Test
  func optionalBoolWithValue() throws {
    let schema = Bool?.schema
    try schema.test(true, isCodedAs: "{\"value\":true}")
    try schema.test(false, isCodedAs: "{\"value\":false}")
  }

  @Test
  func optionalBoolWithNil() throws {
    let schema = Bool?.schema
    try schema.test(nil, isCodedAs: "{}")
  }

  @Test
  func optionalDoubleWithValue() throws {
    let schema = Double?.schema
    try schema.test(3.14, isCodedAs: "{\"value\":3.14}")
  }

  @Test
  func optionalArrayWithValue() throws {
    let schema = [String]?.schema
    try schema.test(["a", "b"], isCodedAs: "{\"value\":[\"a\",\"b\"]}")
  }

  @Test
  func optionalArrayWithNil() throws {
    let schema = [String]?.schema
    try schema.test(nil, isCodedAs: "{}")
  }

  @Test
  func optionalEmptyArray() throws {
    let schema = [String]?.schema
    try schema.test([], isCodedAs: "{\"value\":[]}")
  }

}

@Suite("Optional Schema Decoding")
struct OptionalSchemaDecodingTests {

  @Test
  func decodeOptionalStringWithValue() throws {
    let schema = String?.schema
    try schema.test("{\"value\":\"hello\"}", decodesAs: "hello")
  }

  @Test
  func decodeOptionalStringWithNil() throws {
    let schema = String?.schema
    try schema.test("{}", decodesAs: nil)
  }

  @Test
  func decodeOptionalIntWithValue() throws {
    let schema = Int?.schema
    try schema.test("{\"value\":42}", decodesAs: 42)
  }

  @Test
  func decodeOptionalIntWithNil() throws {
    let schema = Int?.schema
    try schema.test("{}", decodesAs: nil)
  }

  @Test
  func decodeOptionalBoolWithValue() throws {
    let schema = Bool?.schema
    try schema.test("{\"value\":true}", decodesAs: true)
    try schema.test("{\"value\":false}", decodesAs: false)
  }

  @Test
  func decodeOptionalArrayWithValue() throws {
    let schema = [String]?.schema
    try schema.test("{\"value\":[\"a\",\"b\"]}", decodesAs: ["a", "b"])
  }

  @Test
  func decodeOptionalArrayWithNil() throws {
    let schema = [String]?.schema
    try schema.test("{}", decodesAs: nil)
  }

  @Test
  func decodeWithWhitespace() throws {
    let schema = String?.schema
    try schema.test("{ \"value\" : \"hello\" }", decodesAs: "hello")
    try schema.test("{ }", decodesAs: nil)
  }

  @Test
  func chunkedDecoding() throws {
    let schema = String?.schema
    try schema.test(
      ["{", "\"value\"", ":", "\"hello\"", "}"],
      decodesAs: "hello"
    )
    try schema.test(
      ["{", "}"],
      decodesAs: nil
    )
  }

}

@Suite("Optional Schema Meta")
struct OptionalSchemaMetaTests {

  @Test
  func optionalStringMetaSchema() throws {
    let schema = String?.schema
    let context = SchemaCoding.Support.SchemaContext()
    let metaSchema = schema.metaSchema(in: context)

    try metaSchema.test(
      schema,
      encodesAs: """
        {
          "properties": {
            "value": {
              "type": "string"
            }
          },
          "required": [

          ]
        }
        """,
      prettyPrint: true
    )
  }

  @Test
  func optionalIntMetaSchema() throws {
    let schema = Int?.schema
    let context = SchemaCoding.Support.SchemaContext()
    let metaSchema = schema.metaSchema(in: context)

    try metaSchema.test(
      schema,
      encodesAs: """
        {
          "properties": {
            "value": {
              "type": "integer"
            }
          },
          "required": [

          ]
        }
        """,
      prettyPrint: true
    )
  }

  @Test
  func optionalArrayMetaSchema() throws {
    let schema = [String]?.schema
    let context = SchemaCoding.Support.SchemaContext()
    let metaSchema = schema.metaSchema(in: context)

    try metaSchema.test(
      schema,
      encodesAs: """
        {
          "properties": {
            "value": {
              "items": {
                "type": "string"
              }
            }
          },
          "required": [

          ]
        }
        """,
      prettyPrint: true
    )
  }

}

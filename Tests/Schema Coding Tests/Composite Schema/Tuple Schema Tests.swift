import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Tuple Schema")
struct TupleSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testTwoElementTuple() throws {
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.BooleanSchema(),
          SchemaCoding.Support.BooleanSchema()
      )
      try schema.test((true, false), isCodedAs: "[true,false]")
      try schema.test((false, true), isCodedAs: "[false,true]")
    }

    @Test
    func testThreeElementTuple() throws {
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.BooleanSchema(),
          SchemaCoding.Support.BooleanSchema(),
          SchemaCoding.Support.BooleanSchema()
      )
      try schema.test((true, false, true), isCodedAs: "[true,false,true]")
    }

    @Test
    func testMixedTypeTuple() throws {
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.schema(representing: String.self),
          SchemaCoding.Support.schema(representing: Int.self),
          SchemaCoding.Support.BooleanSchema()
      )
      try schema.test(("hello", 42, true), isCodedAs: #"["hello",42,true]"#)
    }

    @Test
    func testNestedTuple() throws {
      // For nested tuples, use the flatten variant
      let innerSchema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.BooleanSchema(),
          SchemaCoding.Support.BooleanSchema()
      )
      let outerSchema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.schema(representing: String.self),
          innerSchema
      )

      try outerSchema.test(
        ("test", (true, false)),
        flatten: { ($0.0, $0.1.0, $0.1.1) },
        isCodedAs: #"["test",[true,false]]"#
      )
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.BooleanSchema(),
          SchemaCoding.Support.schema(representing: Int.self)
      )
      try schema.test(
        encodesAs: """
          {
            "prefixItems": [
              {
                "type": "boolean"
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

  }

}
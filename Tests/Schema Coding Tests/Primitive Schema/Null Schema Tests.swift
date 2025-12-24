import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Null Schema")
struct NullSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testNullCoding() throws {
      let schema = SchemaCoding.Support.NullSchema()
      try schema.test((), isCodedAs: "null")
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      try SchemaCoding.Support.NullSchema()
        .test(encodesAs: #"{"type":"null"}"#)
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support.NullSchema(description: "A null value")
        .test(encodesAs: #"{"description":"A null value","type":"null"}"#)
    }

  }

}

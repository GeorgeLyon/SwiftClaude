import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Never Schema")
struct NeverSchemaTests {

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      try SchemaCoding.Support.NeverSchema()
        .test(
          encodesAs: """
            {
              "not": {

              }
            }
            """
        )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support.NeverSchema(description: "An impossible value")
        .test(
          encodesAs: """
            {
              "description": "An impossible value",
              "not": {

              }
            }
            """
        )
    }

  }

}

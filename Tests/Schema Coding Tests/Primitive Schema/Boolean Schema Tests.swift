import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Boolean Schema")
struct BooleanSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testTrueCoding() throws {
      try test(true, isCodedAs: "true")
    }

    @Test
    func testFalseCoding() throws {
      try test(false, isCodedAs: "false")
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      try SchemaCoding.Support
        .schema(representing: Bool.self)
        .test(
          encodesAs: """
            {
              "type": "boolean"
            }
            """
        )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support
        .schema(representing: Bool.self, description: "A boolean value")
        .test(
          encodesAs: """
            {
              "description": "A boolean value",
              "type": "boolean"
            }
            """
        )
    }

  }

}

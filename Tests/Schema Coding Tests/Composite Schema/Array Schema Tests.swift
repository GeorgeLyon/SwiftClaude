import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Array Schema")
struct ArraySchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testEmptyArray() throws {
      let schema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      try schema.test([], isCodedAs: "[]")
    }

    @Test
    func testSingleElementArray() throws {
      let schema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      try schema.test([true], isCodedAs: "[true]")
    }

    @Test
    func testMultipleElementArray() throws {
      let schema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      try schema.test([true, false, true], isCodedAs: "[true,false,true]")
    }

    @Test
    func testArrayWithSchemaCodableElements() throws {
      try test([1, 2, 3], isCodedAs: "[1,2,3]")
      try test(["a", "b", "c"], isCodedAs: #"["a","b","c"]"#)
      try test([true, false, true], isCodedAs: "[true,false,true]")
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      try SchemaCoding.Support
        .schema(representing: [Int].self)
        .test(
          encodesAs: """
            {
              "items": {
                "type": "integer"
              }
            }
            """,
          prettyPrint: true
        )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support
        .schema(representing: [Int].self, description: "An array of integers")
        .test(
          encodesAs: """
            {
              "description": "An array of integers",
              "items": {
                "type": "integer"
              }
            }
            """,
          prettyPrint: true
        )
    }

  }

}
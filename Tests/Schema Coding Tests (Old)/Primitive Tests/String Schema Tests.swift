import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("String")
struct StringSchemaTests {

  @Test
  private func testSchema() throws {
    try SchemaCoding.Support
      .schema(
        representing: String.self
      )
      .test(encodesAs: #"{"type":"string"}"#)

    try SchemaCoding.Support
      .schema(
        representing: String.self,
        description: "A string"
      )
      .test(encodesAs: #"{"description":"A string","type":"string"}"#)
  }

  @Test
  private func testCoding() throws {
    try test("foo", isCodedAs: "\"foo\"")
    try test("bar", isCodedAs: "\"bar\"")
  }

}

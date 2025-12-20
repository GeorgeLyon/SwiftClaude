import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Boolean")
struct BooleanSchemaTests {

  @Test
  private func testCoding() throws {
    try test(true, isCodedAs: "true")
    try test(false, isCodedAs: "false")
  }

  @Test
  private func testSchema() throws {
    try SchemaCoding.Support
      .schema(
        representing: Bool.self
      )
      .test(encodesAs: #"{"type":"boolean"}"#)

    try SchemaCoding.Support
      .schema(
        representing: Bool.self,
        description: "A boolean"
      )
      .test(encodesAs: #"{"description":"A boolean","type":"boolean"}"#)
  }

}

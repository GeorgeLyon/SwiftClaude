import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Schema Coding")
struct SchemaCodingTests {

  @Test
  func stringCoding() throws {
    try test("hello", isCodedAs: "\"hello\"")
  }

}

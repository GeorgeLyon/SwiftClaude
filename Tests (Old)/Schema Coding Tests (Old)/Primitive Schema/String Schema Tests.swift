import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("String Schema")
struct StringSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testEmptyString() throws {
      try test("", isCodedAs: "\"\"")
    }

    @Test
    func testSimpleString() throws {
      try test("hello", isCodedAs: #""hello""#)
      try test("world", isCodedAs: #""world""#)
      try test("foo bar", isCodedAs: #""foo bar""#)
    }

    @Test
    func testSpecialCharacters() throws {
      try test("hello\nworld", isCodedAs: #""hello\nworld""#)
      try test("tab\there", isCodedAs: #""tab\there""#)
      try test("quote\"here", isCodedAs: #""quote\"here""#)
      try test("backslash\\test", isCodedAs: #""backslash\\test""#)
    }

    @Test
    func testUnicode() throws {
      try test("unicode: 👍", isCodedAs: #""unicode: 👍""#)
      try test("emoji: 🎉", isCodedAs: #""emoji: 🎉""#)
      try test("日本語", isCodedAs: #""日本語""#)
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      try SchemaCoding.Support
        .schema(representing: String.self)
        .test(
          encodesAs: """
            {
              "type": "string"
            }
            """
        )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support
        .schema(representing: String.self, description: "A string value")
        .test(
          encodesAs: """
            {
              "description": "A string value",
              "type": "string"
            }
            """
        )
    }

  }

}

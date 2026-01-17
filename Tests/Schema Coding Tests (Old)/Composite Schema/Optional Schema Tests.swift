import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Optional Schema")
struct OptionalSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testNilOptional() throws {
      // Optional uses object wrapper with "value" key
      try test(
        nil as Bool?,
        isCodedAs: """
          {

          }
          """
      )
      try test(
        nil as Int?,
        isCodedAs: """
          {

          }
          """
      )
      try test(
        nil as String?,
        isCodedAs: """
          {

          }
          """
      )
    }

    @Test
    func testSomeOptional() throws {
      try test(
        true as Bool?,
        isCodedAs: """
          {
            "value": true
          }
          """
      )
      try test(
        42 as Int?,
        isCodedAs: """
          {
            "value": 42
          }
          """
      )
      try test(
        "hello" as String?,
        isCodedAs: """
          {
            "value": "hello"
          }
          """
      )
    }

    @Test
    func testNestedOptional() throws {
      // Nested optionals: each level adds another object wrapper
      try test(
        .none as Bool??,
        isCodedAs: """
          {

          }
          """
      )
      try test(
        .some(nil) as Bool??,
        isCodedAs: """
          {
            "value": {

            }
          }
          """
      )
      try test(
        .some(true) as Bool??,
        isCodedAs: """
          {
            "value": {
              "value": true
            }
          }
          """
      )
    }

    @Test
    func testDeeplyNestedOptional() throws {
      try test(
        nil as Bool???,
        isCodedAs: """
          {

          }
          """
      )
      try test(
        .some(nil) as Bool???,
        isCodedAs: """
          {
            "value": {

            }
          }
          """
      )
      try test(
        .some(.some(nil)) as Bool???,
        isCodedAs: """
          {
            "value": {
              "value": {

              }
            }
          }
          """
      )
      try test(
        .some(.some(true)) as Bool???,
        isCodedAs: """
          {
            "value": {
              "value": {
                "value": true
              }
            }
          }
          """
      )
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      // Optional schema encodes as an object with optional "value" property
      try SchemaCoding.Support
        .schema(representing: Bool?.self)
        .test(
          encodesAs: """
            {
              "properties": {
                "value": {
                  "type": "boolean"
                }
              }
            }
            """
        )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support
        .schema(representing: Bool?.self, description: "An optional boolean")
        .test(
          encodesAs: """
            {
              "description": "An optional boolean",
              "properties": {
                "value": {
                  "type": "boolean"
                }
              }
            }
            """
        )
    }

  }

}

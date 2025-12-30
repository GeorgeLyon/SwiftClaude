import SchemaCodingTestSupport
import Testing

@testable import Tools

@Suite("@ToolInput Enum")
struct ToolInputEnumTests {
  @ToolInput(
    description: "A enum with multiple cases"
  )
  enum TestEnum: Equatable {
    // A string
    case first(String)
    case `continue`(x: Int)
    case fourth(x: String, y: Int)
    case fifth
  }

  @ToolInput
  enum SimpleEnum: Equatable {
    case one
    case two
    case three
  }

  @ToolInput(
    description: "A simple string-based enum"
  )
  enum StringEnum: String, CaseIterable, Equatable {
    case one
    case two
    case three
  }

  /* An integer-based enum */
  @ToolInput
  enum IntEnum: Int, CaseIterable, Equatable {
    case zero = 0
    case one = 1
    case two = 2
  }

  @ToolInput(
    description: "An enum with only one case"
  )
  enum SingleCaseEnum: Equatable {
    @SchemaCase(
      description: "The only case"
    )
    case only(String)
  }

  @Test
  private func testEnumSchemaEncoding() throws {
    try TestEnum.schema.test(
      encodesAs: """
        {
          "description": "A enum with multiple cases",
          "properties": {
            "first": {
              "type": "string"
            },
            "continue": {
              "properties": {
                "x": {
                  "type": "integer"
                }
              },
              "required": [
                "x"
              ]
            },
            "third": {
              "prefixItems": [
                {
                  "type": "string"
                },
                {
                  "description": "x",
                  "type": "integer"
                }
              ]
            },
            "fourth": {
              "properties": {
                "x": {
                  "type": "string"
                },
                "y": {
                  "type": "integer"
                }
              },
              "required": [
                "x",
                "y"
              ]
            },
            "fifth": {
              "properties": {

              }
            }
          },
          "minProperties": 1,
          "maxProperties": 1
        }
        """
    )
  }

  @Test
  private func testEnumValueEncoding() throws {
    try TestEnum.schema.test(
      .first("a"),
      encodesAs: """
        {
          "first": "a"
        }
        """
    )

    try TestEnum.schema.test(
      .fifth,
      encodesAs: """
        {
          "fifth": {

          }
        }
        """
    )
  }

  @Test
  private func testEnumValueDecoding() throws {
    try TestEnum.schema.test(
      """
      {
        "first": "a"
      }
      """,
      decodesAs: .first("a")
    )
  }

  @Test
  private func testCaseIterableStringEnumSchemaEncoding() throws {
    try StringEnum.schema.test(
      encodesAs: """
        {
          "description": "A simple string-based enum",
          "enum": [
            "one",
            "two",
            "three"
          ]
        }
        """
    )
  }

  @Test
  private func testCaseIterableStringEnumValueEncoding() throws {
    try StringEnum.schema.test(
      .two,
      encodesAs: """
        "two"
        """
    )
  }

  @Test
  private func testCaseIterableStringEnumValueDecoding() throws {
    try StringEnum.schema.test(
      """
      "three"
      """,
      decodesAs: .three
    )
  }

  @Test
  private func testCaseIterableIntEnumSchemaEncoding() throws {
    try IntEnum.schema.test(
      encodesAs: """
        {
          "enum": [
            0,
            1,
            2
          ]
        }
        """
    )
  }

  @Test
  private func testCaseIterableIntEnumValueEncoding() throws {
    try IntEnum.schema.test(
      .one,
      encodesAs: """
        1
        """
    )
  }

  @Test
  private func testCaseIterableIntEnumValueDecoding() throws {
    try IntEnum.schema.test(
      """
      2
      """,
      decodesAs: .two
    )
  }

  @Test
  private func testSingleCaseEnumSchemaEncoding() throws {
    try SingleCaseEnum.schema.test(
      encodesAs: """
        {
          "description": "An enum with only one case\\nThe only case",
          "type": "string"
        }
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueEncoding() throws {
    try SingleCaseEnum.schema.test(
      .only("test"),
      encodesAs: """
        "test"
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueDecoding() throws {
    try SingleCaseEnum.schema.test(
      """
      "value"
      """,
      decodesAs: .only("value")
    )
  }

  @Test
  private func testSimpleEnumSchemaEncoding() throws {
    try SimpleEnum.schema.test(
      encodesAs: """
        {
          "enum": [
            "one",
            "two",
            "three"
          ]
        }
        """
    )
  }

  @Test
  private func testSimpleEnumValueEncoding() throws {
    try SimpleEnum.schema.test(
      .two,
      encodesAs: """
        "two"
        """
    )
  }

  @Test
  private func testSimpleEnumValueDecoding() throws {
    try SimpleEnum.schema.test(
      """
      "three"
      """,
      decodesAs: .three
    )
  }

}

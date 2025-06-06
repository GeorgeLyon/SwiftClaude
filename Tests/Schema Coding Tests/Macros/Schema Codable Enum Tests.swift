import Testing

@testable import SchemaCoding

@Suite("Schema Codable Enum")
struct SchemaCodableEnumTests {

  /// A enum with multiple cases
  @SchemaCodable
  enum TestEnum: Equatable {
    // A string
    case first(String)
    case `continue`(x: Int)
    case third(String, x: Int)
    case fourth(x: String, y: Int)
    case fifth
  }

  /// A simple enum
  @SchemaCodable
  enum SimpleEnum: Equatable {
    case one
    case two
    case three
  }

  /// A simple string-based enum
  @SchemaCodable
  enum StringEnum: String, CaseIterable, Equatable {
    case one
    case two
    case three
  }

  /* An integer-based enum */
  @SchemaCodable
  enum IntEnum: Int, CaseIterable, Equatable {
    case zero = 0
    case one = 1
    case two = 2
  }

  // An enum with only one case
  @SchemaCodable
  enum SingleCaseEnum: Equatable {
    /**
     The only case
     */
    case only(String)
  }

  @Test
  private func testEnumSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: TestEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "A enum with multiple cases",
          "properties": {
            "first": {
              "description": "A string",
              "type": "string"
            },
            "continue": {
              "type": "integer"
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
              "type": "null"
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
    let schema = SchemaSupport.schema(representing: TestEnum.self)
    #expect(
      schema.encodedJSON(for: .first("a")) == """
        {
          "first": "a"
        }
        """
    )

    #expect(
      schema.encodedJSON(for: .fifth) == """
        {
          "fifth": null
        }
        """
    )
  }

  @Test
  private func testEnumValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: TestEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          {
            "first": "a"
          }
          """) == .first("a")
    )
  }

  @Test
  private func testCaseIterableStringEnumSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: StringEnum.self)
    #expect(
      schema.schemaJSON == """
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
    let schema = SchemaSupport.schema(representing: StringEnum.self)
    #expect(
      schema.encodedJSON(for: .two) == """
        "two"
        """
    )
  }

  @Test
  private func testCaseIterableStringEnumValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: StringEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "three"
          """) == .three
    )
  }

  @Test
  private func testCaseIterableIntEnumSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: IntEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "An integer-based enum",
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
    let schema = SchemaSupport.schema(representing: IntEnum.self)
    #expect(
      schema.encodedJSON(for: .one) == """
        1
        """
    )
  }

  @Test
  private func testCaseIterableIntEnumValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: IntEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          2
          """) == .two
    )
  }

  @Test
  private func testSingleCaseEnumSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "An enum with only one case\\nThe only case",
          "type": "string"
        }
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueEncoding() throws {
    let schema = SchemaSupport.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.encodedJSON(for: .only("test")) == """
        "test"
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "value"
          """) == .only("value")
    )
  }

  @Test
  private func testSimpleEnumSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: SimpleEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "A simple enum",
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
    let schema = SchemaSupport.schema(representing: SimpleEnum.self)
    #expect(
      schema.encodedJSON(for: .two) == """
        "two"
        """
    )
  }

  @Test
  private func testSimpleEnumValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: SimpleEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "three"
          """) == .three
    )
  }
}

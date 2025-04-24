import Testing

@testable import Tool

@Suite("Enum")
struct EnumSchemaTests {

  private enum TestEnum: ToolInput.SchemaCodable, Equatable {

    case first(String)
    case second(Int)
    case third(String, x: Int)
    case fourth(x: String, y: Int)

    static let toolInputSchema: some ToolInput.Schema<Self> = {
      let associatedValues_first = ToolInput.enumCaseAssociatedValuesSchema(
        keyedBy: CaseKey.First.self,
        values: (
          key: nil,
          schema: ToolInput.schema(representing: String.self)
        )
      )

      let associatedValues_second = ToolInput.enumCaseAssociatedValuesSchema(
        keyedBy: CaseKey.Second.self,
        values: (
          key: nil,
          schema: ToolInput.schema(representing: Int.self)
        )
      )

      let associatedValues_third = ToolInput.enumCaseAssociatedValuesSchema(
        keyedBy: CaseKey.Third.self,
        values: (
          (
            key: nil,
            schema: ToolInput.schema(representing: String.self)
          ),
          (
            key: .x,
            schema: ToolInput.schema(representing: Int.self)
          )
        )
      )

      let associatedValues_fourth = ToolInput.enumCaseAssociatedValuesSchema(
        keyedBy: CaseKey.Fourth.self,
        values: (
          (
            key: .x,
            schema: ToolInput.schema(representing: String.self)
          ),
          (
            key: .y,
            schema: ToolInput.schema(representing: Int.self)
          )
        )
      )

      return ToolInput.enumSchema(
        representing: Self.self,
        description: "A simple enum with multiple cases",
        keyedBy: CaseKey.self,
        cases: (
          (
            key: .first,
            description: "A string",
            associatedValueSchema: associatedValues_first,
            initializer: { @Sendable first in .first(first) }
          ),
          (
            key: .second,
            description: nil,
            associatedValueSchema: associatedValues_second,
            initializer: { @Sendable second in .second(second) }
          ),
          (
            key: .third,
            description: nil,
            associatedValueSchema: associatedValues_third,
            initializer: { @Sendable third in Self.third(third.0, x: third.1) }
          ),
          (
            key: .fourth,
            description: nil,
            associatedValueSchema: associatedValues_fourth,
            initializer: { @Sendable fourth in Self.fourth(x: fourth.0, y: fourth.1) }
          )
        ),
        encodeValue: { value, encodeFirst, encodeSecond, encodeThird, encodeFourth in
          switch value {
          case .first(let first): try encodeFirst((first))
          case .second(let second): try encodeSecond((second))
          case .third(let third_0, let third_x): try encodeThird((third_0, third_x))
          case let .fourth(x, y): try encodeFourth((x, y))
          }
        }
      )
    }()

    private enum CaseKey: Swift.CodingKey {
      case first, second, third, fourth

      enum First: Swift.CodingKey {
      }
      enum Second: Swift.CodingKey {
      }
      enum Third: Swift.CodingKey {
        case x
      }
      enum Fourth: Swift.CodingKey {
        case x, y
      }
    }

  }

  private enum SimpleEnum: ToolInput.SchemaCodable, Equatable {
    case one
    case two
    case three

    static let toolInputSchema: some ToolInput.Schema<Self> = {
      let associatedValues_one = ToolInput.enumCaseAssociatedValuesSchema(
        keyedBy: CaseKey.Empty.self,
        values: ()
      )
      let associatedValues_two = ToolInput.enumCaseAssociatedValuesSchema(
        keyedBy: CaseKey.Empty.self,
        values: ()
      )
      let associatedValues_three = ToolInput.enumCaseAssociatedValuesSchema(
        keyedBy: CaseKey.Empty.self,
        values: ()
      )

      return ToolInput.enumSchema(
        representing: Self.self,
        description: "A simple string-based enum",
        keyedBy: CaseKey.self,
        cases: (
          (
            key: .one,
            description: nil,
            associatedValueSchema: associatedValues_one,
            initializer: { @Sendable _ in .one }
          ),
          (
            key: .two,
            description: nil,
            associatedValueSchema: associatedValues_two,
            initializer: { @Sendable _ in .two }
          ),
          (
            key: .three,
            description: nil,
            associatedValueSchema: associatedValues_three,
            initializer: { @Sendable _ in .three }
          )
        ),
        encodeValue: { @Sendable value, encodeOne, encodeTwo, encodeThree in
          switch value {
          case .one: try encodeOne(())
          case .two: try encodeTwo(())
          case .three: try encodeThree(())
          }
        }
      )
    }()

    private enum CaseKey: Swift.CodingKey {
      case one, two, three

      enum Empty: CodingKey {

      }
    }
  }

  private enum StringEnum: String, CaseIterable, ToolInput.SchemaCodable, Equatable {
    case one
    case two
    case three

    static let toolInputSchema: some ToolInput.Schema<Self> = ToolInput.enumSchema(
      representing: Self.self,
      description: "A simple string-based enum"
    )
  }

  private enum IntEnum: Int, CaseIterable, ToolInput.SchemaCodable, Equatable {
    case zero = 0
    case one = 1
    case two = 2

    static let toolInputSchema: some ToolInput.Schema<Self> = ToolInput.enumSchema(
      representing: Self.self,
      description: "An integer-based enum"
    )
  }

  // Enum with a single case for SingleCaseEnumSchema
  private enum SingleCaseEnum: ToolInput.SchemaCodable, Equatable {
    case only(String)

    static let toolInputSchema: some ToolInput.Schema<Self> = ToolInput.enumSchema(
      representing: Self.self,
      description: "An enum with only one case",
      keyedBy: CaseKey.self,
      cases: ((
        key: .only,
        description: "The only case",
        associatedValueSchema: ToolInput.schema(),
        initializer: { @Sendable value in .only(value) }
      )),
      encodeValue: { value, encode in
        if case .only(let value) = value {
          try encode(value)
        }
      }
    )

    private enum CaseKey: Swift.CodingKey {
      case only
    }
  }

  @Test
  private func testEnumSchemaEncoding() throws {
    let schema = ToolInput.schema(representing: TestEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "additionalProperties" : false,
          "description" : "A simple enum with multiple cases",
          "maxProperties" : 1,
          "minProperties" : 1,
          "properties" : {
            "first" : {
              "description" : "A string",
              "type" : "string"
            },
            "fourth" : {
              "additionalProperties" : false,
              "properties" : {
                "x" : {
                  "type" : "string"
                },
                "y" : {
                  "type" : "integer"
                }
              },
              "required" : [
                "x",
                "y"
              ],
              "type" : "object"
            },
            "second" : {
              "type" : "integer"
            },
            "third" : {
              "items" : false,
              "minItems" : 2,
              "prefixItems" : [
                {
                  "type" : "string"
                },
                {
                  "description" : "x",
                  "type" : "integer"
                }
              ],
              "type" : "array"
            }
          },
          "type" : "object"
        }
        """
    )
  }

  @Test
  private func testEnumValueEncoding() throws {
    let schema = ToolInput.schema(representing: TestEnum.self)
    #expect(
      schema.encodedJSON(for: .first("a")) == """
        {
          "first" : "a"
        }
        """
    )
  }

  @Test
  private func testEnumValueDecoding() throws {
    let schema = ToolInput.schema(representing: TestEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          {
            "first" : "a"
          }
          """) == .first("a")
    )
  }

  @Test
  private func testCaseIterableStringEnumSchemaEncoding() throws {
    let schema = ToolInput.schema(representing: StringEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description" : "A simple string-based enum",
          "enum" : [
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
    let schema = ToolInput.schema(representing: StringEnum.self)
    #expect(
      schema.encodedJSON(for: .two) == """
        "two"
        """
    )
  }

  @Test
  private func testCaseIterableStringEnumValueDecoding() throws {
    let schema = ToolInput.schema(representing: StringEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "three"
          """) == .three
    )
  }

  @Test
  private func testCaseIterableIntEnumSchemaEncoding() throws {
    let schema = ToolInput.schema(representing: IntEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description" : "An integer-based enum",
          "enum" : [
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
    let schema = ToolInput.schema(representing: IntEnum.self)
    #expect(
      schema.encodedJSON(for: .one) == """
        1
        """
    )
  }

  @Test
  private func testCaseIterableIntEnumValueDecoding() throws {
    let schema = ToolInput.schema(representing: IntEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          2
          """) == .two
    )
  }

  @Test
  private func testSingleCaseEnumSchemaEncoding() throws {
    let schema = ToolInput.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description" : "An enum with only one case\\nThe only case",
          "type" : "string"
        }
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueEncoding() throws {
    let schema = ToolInput.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.encodedJSON(for: .only("test")) == """
        "test"
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueDecoding() throws {
    let schema = ToolInput.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "value"
          """) == .only("value")
    )
  }

  @Test
  private func testSimpleEnumSchemaEncoding() throws {
    let schema = ToolInput.schema(representing: SimpleEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description" : "A simple string-based enum",
          "enum" : [
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
    let schema = ToolInput.schema(representing: SimpleEnum.self)
    #expect(
      schema.encodedJSON(for: .two) == """
        "two"
        """
    )
  }

  @Test
  private func testSimpleEnumValueDecoding() throws {
    let schema = ToolInput.schema(representing: SimpleEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "three"
          """) == .three
    )
  }
}

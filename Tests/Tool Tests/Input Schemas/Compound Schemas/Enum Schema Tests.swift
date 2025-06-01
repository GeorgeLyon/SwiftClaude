import Testing

@testable import Tool

@Suite("Enum")
struct EnumSchemaTests {

  private enum TestEnum: ToolInput.SchemaCodable, Equatable {

    case first(String)
    case second(x: Int)
    case third(String, x: Int)
    case fourth(x: String, y: Int)
    case fifth

    static let toolInputSchema: some ToolInput.Schema<Self> = {
      let associatedValues_first = ToolInput.enumCaseAssociatedValuesSchema(
        values: ((
          key: CaseKey.First?.none,
          schema: ToolInput.schema(representing: String.self)
        )),
        keyedBy: CaseKey.First.self
      )

      let associatedValues_second = ToolInput.enumCaseAssociatedValuesSchema(
        values: ((
          key: CaseKey.Second.x,
          schema: ToolInput.schema(representing: Int.self)
        )),
        keyedBy: CaseKey.Second.self
      )

      let associatedValues_third = ToolInput.enumCaseAssociatedValuesSchema(
        values: (
          (
            key: CaseKey.Third?.none,
            schema: ToolInput.schema(representing: String.self)
          ),
          (
            key: CaseKey.Third?.some(.x),
            schema: ToolInput.schema(representing: Int.self)
          )
        ),
        keyedBy: CaseKey.Third.self
      )

      let associatedValues_fourth = ToolInput.enumCaseAssociatedValuesSchema(
        values: (
          (
            key: CaseKey.Fourth?.some(.x),
            schema: ToolInput.schema(representing: String.self)
          ),
          (
            key: CaseKey.Fourth?.some(.y),
            schema: ToolInput.schema(representing: Int.self)
          )
        ),
        keyedBy: CaseKey.Fourth.self
      )

      let associatedValues_fifth = ToolInput.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Fifth.self
      )

      return ToolInput.enumSchema(
        representing: Self.self,
        description: "A simple enum with multiple cases",
        keyedBy: CaseKey.self,
        cases: (
          (
            key: .first,
            description: "A string",
            associatedValuesSchema: associatedValues_first,
            initializer: { @Sendable first in .first(first) }
          ),
          (
            key: .second,
            description: String?.none,
            associatedValuesSchema: associatedValues_second,
            initializer: { @Sendable second in .second(x: second) }
          ),
          (
            key: .third,
            description: nil,
            associatedValuesSchema: associatedValues_third,
            initializer: { @Sendable third in Self.third(third.0, x: third.1) }
          ),
          (
            key: .fourth,
            description: nil,
            associatedValuesSchema: associatedValues_fourth,
            initializer: { @Sendable fourth in Self.fourth(x: fourth.0, y: fourth.1) }
          ),
          (
            key: .fifth,
            description: nil,
            associatedValuesSchema: associatedValues_fifth,
            initializer: { @Sendable fifth in Self.fifth }
          )
        ),
        encodeValue: { value, encodeFirst, encodeSecond, encodeThird, encodeFourth, encodeFifth in
          switch value {
          case .first(let first): try encodeFirst((first))
          case .second(let second): try encodeSecond((second))
          case .third(let third_0, let third_x): try encodeThird((third_0, third_x))
          case let .fourth(x, y): try encodeFourth((x, y))
          case .fifth: try encodeFifth(())
          }
        }
      )
    }()

    private enum CaseKey: Swift.CodingKey {
      case first, second, third, fourth, fifth

      enum First: Swift.CodingKey {
      }
      enum Second: Swift.CodingKey {
        case x
      }
      enum Third: Swift.CodingKey {
        case x
      }
      enum Fourth: Swift.CodingKey {
        case x, y
      }
      enum Fifth: Swift.CodingKey {
      }
    }

  }

  private enum SimpleEnum: ToolInput.SchemaCodable, Equatable {
    case one
    case two
    case three

    static let toolInputSchema: some ToolInput.Schema<Self> = {
      let associatedValues_one = ToolInput.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Empty.self
      )
      let associatedValues_two = ToolInput.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Empty.self
      )
      let associatedValues_three = ToolInput.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Empty.self
      )

      return ToolInput.enumSchema(
        representing: Self.self,
        description: "A simple string-based enum",
        keyedBy: CaseKey.self,
        cases: (
          (
            key: .one,
            description: nil,
            associatedValuesSchema: associatedValues_one,
            initializer: { @Sendable _ in .one }
          ),
          (
            key: .two,
            description: nil,
            associatedValuesSchema: associatedValues_two,
            initializer: { @Sendable _ in .two }
          ),
          (
            key: .three,
            description: nil,
            associatedValuesSchema: associatedValues_three,
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
        associatedValuesSchema: ToolInput.schema(),
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
          "description" : "A simple enum with multiple cases",
          "properties" : {
            "first" : {
              "description" : "A string",
              "type" : "string"
            },
            "second" : {
              "type" : "integer"
            },
            "third" : {
              "prefixItems" : [
                {
                  "type" : "string"
                },
                {
                  "description" : "x",
                  "type" : "integer"
                }
              ]
            },
            "fourth" : {
              "prefixItems" : [
                {
                  "description" : "x",
                  "type" : "string"
                },
                {
                  "description" : "y",
                  "type" : "integer"
                }
              ]
            },
            "fifth" : {
              "type" : "null"
            }
          },
          "minProperties" : 1,
          "maxProperties" : 1
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

    #expect(
      schema.encodedJSON(for: .fifth) == """
        {
          "fifth" : null
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

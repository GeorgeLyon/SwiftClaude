import Testing

@testable import SchemaCoding

@Suite("Enum (Standard)")
struct EnumSchemaStandardTests {

  private enum TestEnum: SchemaCodable, Equatable {

    case first(String)
    case second(x: Int)
    case third(String, x: Int)
    case fourth(x: String, y: Int)
    case fifth

    static let schema: some SchemaCoding.Schema<Self> = {
      let associatedValues_first = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: ((
          key: CaseKey.First?.none,
          schema: SchemaProvider.schema(representing: String.self)
        )),
        keyedBy: CaseKey.First.self
      )

      let associatedValues_second = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: ((
          key: CaseKey.Second.x,
          schema: SchemaProvider.schema(representing: Int.self)
        )),
        keyedBy: CaseKey.Second.self
      )

      let associatedValues_third = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: (
          (
            key: CaseKey.Third?.none,
            schema: SchemaProvider.schema(representing: String.self)
          ),
          (
            key: CaseKey.Third?.some(.x),
            schema: SchemaProvider.schema(representing: Int.self)
          )
        ),
        keyedBy: CaseKey.Third.self
      )

      let associatedValues_fourth = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: (
          (
            key: CaseKey.Fourth?.some(.x),
            schema: SchemaProvider.schema(representing: String.self)
          ),
          (
            key: CaseKey.Fourth?.some(.y),
            schema: SchemaProvider.schema(representing: Int.self)
          )
        ),
        keyedBy: CaseKey.Fourth.self
      )

      let associatedValues_fifth = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Fifth.self
      )

      return SchemaProvider.enumSchema(
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
        caseEncoder: { value, encodeFirst, encodeSecond, encodeThird, encodeFourth, encodeFifth in
          switch value {
          case .first(let first): encodeFirst((first))
          case .second(let second): encodeSecond((second))
          case .third(let third_0, let third_x): encodeThird((third_0, third_x))
          case let .fourth(x, y): encodeFourth((x, y))
          case .fifth: encodeFifth(())
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

  private enum SimpleEnum: SchemaCodable, Equatable {
    case one
    case two
    case three

    static let schema: some SchemaCoding.Schema<Self> = {
      let associatedValues_one = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Empty.self
      )
      let associatedValues_two = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Empty.self
      )
      let associatedValues_three = SchemaProvider.enumCaseAssociatedValuesSchema(
        values: (),
        keyedBy: CaseKey.Empty.self
      )

      return SchemaProvider.enumSchema(
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
        caseEncoder: { @Sendable value, encodeOne, encodeTwo, encodeThree in
          switch value {
          case .one: encodeOne(())
          case .two: encodeTwo(())
          case .three: encodeThree(())
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

  // Enum with a single case for SingleCaseEnumSchema
  private enum SingleCaseEnum: SchemaCodable, Equatable {
    case only(String)

    static let schema: some SchemaCoding.Schema<Self> = SchemaProvider.enumSchema(
      representing: Self.self,
      description: "An enum with only one case",
      keyedBy: CaseKey.self,
      cases: ((
        key: .only,
        description: "The only case",
        associatedValuesSchema: SchemaProvider.schema(representing: String.self),
        initializer: { @Sendable value in Self.only(value) }
      )),
      caseEncoder: { value, encode in
        switch value {
        case .only(let value): encode(value)
        }
      }
    )

    private enum CaseKey: Swift.CodingKey {
      case only
    }
  }

  @Test
  private func testEnumSchemaEncoding() throws {
    let schema = SchemaProvider.schema(representing: TestEnum.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "A simple enum with multiple cases",
          "properties": {
            "first": {
              "description": "A string",
              "type": "string"
            },
            "second": {
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
              "prefixItems": [
                {
                  "description": "x",
                  "type": "string"
                },
                {
                  "description": "y",
                  "type": "integer"
                }
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
    let schema = SchemaProvider.schema(representing: TestEnum.self)
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
    let schema = SchemaProvider.schema(representing: TestEnum.self)
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
  private func testSingleCaseEnumSchemaEncoding() throws {
    let schema = SchemaProvider.schema(representing: SingleCaseEnum.self)
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
    let schema = SchemaProvider.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.encodedJSON(for: .only("test")) == """
        "test"
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueDecoding() throws {
    let schema = SchemaProvider.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "value"
          """) == .only("value")
    )
  }

  @Test
  private func testSimpleEnumSchemaEncoding() throws {
    let schema = SchemaProvider.schema(representing: SimpleEnum.self)
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
  private func testSimpleEnumValueEncoding() throws {
    let schema = SchemaProvider.schema(representing: SimpleEnum.self)
    #expect(
      schema.encodedJSON(for: .two) == """
        "two"
        """
    )
  }

  @Test
  private func testSimpleEnumValueDecoding() throws {
    let schema = SchemaProvider.schema(representing: SimpleEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "three"
          """) == .three
    )
  }

  @Test
  private func testStandardEnumValueEncoding() throws {
    let schema = SchemaProvider.schema(representing: TestEnum.self)
    #expect(
      schema.encodedJSON(for: .first("hello")) == """
        {
          "first": "hello"
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
}

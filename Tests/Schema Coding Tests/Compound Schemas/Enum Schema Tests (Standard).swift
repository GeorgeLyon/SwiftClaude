import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Enum (Standard)")
struct EnumSchemaStandardTests {

  private enum TestEnum: SchemaCoding.SchemaCodingSupport.SchemaCodable, Equatable {

    case first(String)
    case second(x: Int)
    case third(String, x: Int)
    case fourth(x: String, y: Int)
    case fifth

    static let schema: some SchemaCoding.Schema<Self> = {
      let associatedValues_first = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: (
          key: nil,
          schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self)
        )
      )

      let associatedValues_second = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: (
          key: "x" as SchemaCoding.SchemaCodingSupport.CodingKey,
          schema: SchemaCoding.SchemaCodingSupport.schema(representing: Int.self)
        )
      )

      let associatedValues_third = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: (
          (
            key: nil,
            schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self)
          ),
          (
            key: "x" as SchemaCoding.SchemaCodingSupport.CodingKey,
            schema: SchemaCoding.SchemaCodingSupport.schema(representing: Int.self)
          )
        )
      )

      let associatedValues_fourth = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: (
          (
            key: "x" as SchemaCoding.SchemaCodingSupport.CodingKey,
            schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self)
          ),
          (
            key: "y" as SchemaCoding.SchemaCodingSupport.CodingKey,
            schema: SchemaCoding.SchemaCodingSupport.schema(representing: Int.self)
          )
        )
      )

      let associatedValues_fifth = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: ()
      )

      return SchemaCoding.SchemaCodingSupport.enumSchema(
        representing: Self.self,
        description: "A simple enum with multiple cases",
        cases: (
          (
            key: "first" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: "A string",
            schema: associatedValues_first,
            initializer: { @Sendable first in .first(first) }
          ),
          (
            key: "second" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: String?.none,
            schema: associatedValues_second,
            initializer: { @Sendable second in .second(x: second) }
          ),
          (
            key: "third" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: nil,
            schema: associatedValues_third,
            initializer: { @Sendable third in Self.third(third.0, x: third.1) }
          ),
          (
            key: "fourth" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: nil,
            schema: associatedValues_fourth,
            initializer: { @Sendable fourth in Self.fourth(x: fourth.0, y: fourth.1) }
          ),
          (
            key: "fifth" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: nil,
            schema: associatedValues_fifth,
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

  }

  private enum SimpleEnum: SchemaCoding.SchemaCodingSupport.SchemaCodable, Equatable {
    case one
    case two
    case three

    static let schema: some SchemaCoding.Schema<Self> = {
      let associatedValues_one = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: ()
      )
      let associatedValues_two = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: ()
      )
      let associatedValues_three = SchemaCoding.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
        values: ()
      )

      return SchemaCoding.SchemaCodingSupport.enumSchema(
        representing: Self.self,
        description: "A simple string-based enum",
        cases: (
          (
            key: "one" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: nil,
            schema: associatedValues_one,
            initializer: { @Sendable _ in .one }
          ),
          (
            key: "two" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: nil,
            schema: associatedValues_two,
            initializer: { @Sendable _ in .two }
          ),
          (
            key: "three" as SchemaCoding.SchemaCodingSupport.CodingKey,
            description: nil,
            schema: associatedValues_three,
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

  }

  // Enum with a single case for SingleCaseEnumSchema
  private enum SingleCaseEnum: SchemaCoding.SchemaCodable, Equatable {
    case only(String)

    static let schema: some SchemaCoding.Schema<Self> = SchemaCoding.SchemaCodingSupport.enumSchema(
      representing: Self.self,
      description: "An enum with only one case",
      cases: ((
        key: "only" as SchemaCoding.SchemaCodingSupport.CodingKey,
        description: "The only case",
        schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self),
        initializer: { @Sendable value in Self.only(value) }
      )),
      caseEncoder: { value, encode in
        switch value {
        case .only(let value): encode(value)
        }
      }
    )

  }

  @Test
  private func testEnumSchemaEncoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: TestEnum.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: TestEnum.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: TestEnum.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: SingleCaseEnum.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.encodedJSON(for: .only("test")) == """
        "test"
        """
    )
  }

  @Test
  private func testSingleCaseEnumValueDecoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: SingleCaseEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "value"
          """) == .only("value")
    )
  }

  @Test
  private func testSimpleEnumSchemaEncoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: SimpleEnum.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: SimpleEnum.self)
    #expect(
      schema.encodedJSON(for: .two) == """
        "two"
        """
    )
  }

  @Test
  private func testSimpleEnumValueDecoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: SimpleEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "three"
          """) == .three
    )
  }

  @Test
  private func testStandardEnumValueEncoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: TestEnum.self)
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

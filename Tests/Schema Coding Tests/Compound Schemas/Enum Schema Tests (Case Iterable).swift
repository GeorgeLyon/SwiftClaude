import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Enum (Case Iterable)")
struct EnumSchemaCaseIterableTests {

  private enum StringEnum: String, CaseIterable, SchemaCodable, Equatable {
    case one
    case two
    case three

    static let schema: some SchemaCoding.Schema<Self> = SchemaCoding.SchemaCodingSupport.enumSchema(
      representing: Self.self,
      description: "A simple string-based enum"
    )
  }

  private enum IntEnum: Int, CaseIterable, SchemaCodable, Equatable {
    case zero = 0
    case one = 1
    case two = 2

    static let schema: some SchemaCoding.Schema<Self> = SchemaCoding.SchemaCodingSupport.enumSchema(
      representing: Self.self,
      description: "An integer-based enum"
    )
  }

  @Test
  private func testCaseIterableStringEnumSchemaEncoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: StringEnum.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: StringEnum.self)
    #expect(
      schema.encodedJSON(for: .two) == """
        "two"
        """
    )
  }

  @Test
  private func testCaseIterableStringEnumValueDecoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: StringEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          "three"
          """) == .three
    )
  }

  @Test
  private func testCaseIterableIntEnumSchemaEncoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: IntEnum.self)
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
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: IntEnum.self)
    #expect(
      schema.encodedJSON(for: .one) == """
        1
        """
    )
  }

  @Test
  private func testCaseIterableIntEnumValueDecoding() throws {
    let schema = SchemaCoding.SchemaCodingSupport.schema(representing: IntEnum.self)
    #expect(
      schema.value(
        fromJSON: """
          2
          """) == .two
    )
  }
}

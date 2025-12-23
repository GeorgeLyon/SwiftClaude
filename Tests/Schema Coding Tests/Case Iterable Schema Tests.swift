import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Case Iterable Schema")
struct CaseIterableSchemaTests {

  // MARK: - String Enums

  @Suite("String Enums")
  struct StringEnumTests {

    enum Color: String, CaseIterable, Sendable {
      case red
      case green
      case blue
    }

    @Test
    func encodeStringEnum() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Color.self,
        description: nil
      )
      try schema.test(Color.red, isCodedAs: "\"red\"")
      try schema.test(Color.green, isCodedAs: "\"green\"")
      try schema.test(Color.blue, isCodedAs: "\"blue\"")
    }

    @Test
    func decodeStringEnum() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Color.self,
        description: nil
      )
      try schema.test("\"red\"", decodesAs: Color.red)
      try schema.test("\"green\"", decodesAs: Color.green)
      try schema.test("\"blue\"", decodesAs: Color.blue)
    }

    @Test
    func stringEnumWithDescription() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Color.self,
        description: "A color value"
      )
      try schema.test(Color.red, isCodedAs: "\"red\"")
    }

    enum Direction: String, CaseIterable, Sendable {
      case north = "N"
      case south = "S"
      case east = "E"
      case west = "W"
    }

    @Test
    func stringEnumWithCustomRawValues() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Direction.self,
        description: nil
      )
      try schema.test(Direction.north, isCodedAs: "\"N\"")
      try schema.test(Direction.south, isCodedAs: "\"S\"")
      try schema.test(Direction.east, isCodedAs: "\"E\"")
      try schema.test(Direction.west, isCodedAs: "\"W\"")
    }

    @Test
    func decodeStringEnumWithCustomRawValues() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Direction.self,
        description: nil
      )
      try schema.test("\"N\"", decodesAs: Direction.north)
      try schema.test("\"S\"", decodesAs: Direction.south)
      try schema.test("\"E\"", decodesAs: Direction.east)
      try schema.test("\"W\"", decodesAs: Direction.west)
    }

  }

  // MARK: - Integer Enums

  @Suite("Integer Enums")
  struct IntegerEnumTests {

    enum Priority: Int, CaseIterable, Sendable {
      case low = 1
      case medium = 2
      case high = 3
    }

    @Test
    func encodeIntEnum() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Priority.self,
        description: nil
      )
      try schema.test(Priority.low, isCodedAs: "1")
      try schema.test(Priority.medium, isCodedAs: "2")
      try schema.test(Priority.high, isCodedAs: "3")
    }

    @Test
    func decodeIntEnum() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Priority.self,
        description: nil
      )
      try schema.test("1", decodesAs: Priority.low)
      try schema.test("2", decodesAs: Priority.medium)
      try schema.test("3", decodesAs: Priority.high)
    }

    @Test
    func intEnumWithDescription() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Priority.self,
        description: "Task priority level"
      )
      try schema.test(Priority.high, isCodedAs: "3")
    }

    enum StatusCode: UInt8, CaseIterable, Sendable {
      case success = 0
      case warning = 1
      case error = 2
    }

    @Test
    func uint8Enum() throws {
      let schema = SchemaCoding.Support.schema(
        representing: StatusCode.self,
        description: nil
      )
      try schema.test(StatusCode.success, isCodedAs: "0")
      try schema.test(StatusCode.warning, isCodedAs: "1")
      try schema.test(StatusCode.error, isCodedAs: "2")
    }

    @Test
    func decodeUint8Enum() throws {
      let schema = SchemaCoding.Support.schema(
        representing: StatusCode.self,
        description: nil
      )
      try schema.test("0", decodesAs: StatusCode.success)
      try schema.test("1", decodesAs: StatusCode.warning)
      try schema.test("2", decodesAs: StatusCode.error)
    }

  }

  // MARK: - Meta Schema

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    enum Color: String, CaseIterable, Sendable {
      case red
      case green
      case blue
    }

    @Test
    func stringEnumMetaSchema() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Color.self,
        description: nil
      )
      try schema.test(
        encodesAs: """
          {"enum":["red","green","blue"]}
          """,
        prettyPrint: false
      )
    }

    @Test
    func stringEnumMetaSchemaWithDescription() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Color.self,
        description: "A color value"
      )
      try schema.test(
        encodesAs: """
          {"description":"A color value","enum":["red","green","blue"]}
          """,
        prettyPrint: false
      )
    }

    enum Priority: Int, CaseIterable, Sendable {
      case low = 1
      case medium = 2
      case high = 3
    }

    @Test
    func intEnumMetaSchema() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Priority.self,
        description: nil
      )
      try schema.test(
        encodesAs: """
          {"enum":[1,2,3]}
          """,
        prettyPrint: false
      )
    }

    @Test
    func intEnumMetaSchemaWithDescription() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Priority.self,
        description: "Task priority level"
      )
      try schema.test(
        encodesAs: """
          {"description":"Task priority level","enum":[1,2,3]}
          """,
        prettyPrint: false
      )
    }

  }

  // MARK: - Chunked Decoding

  @Suite("Chunked Decoding")
  struct ChunkedDecodingTests {

    enum Color: String, CaseIterable, Sendable {
      case red
      case green
      case blue
    }

    @Test
    func chunkedStringEnumDecoding() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Color.self,
        description: nil
      )
      try schema.test(["\"", "red", "\""], decodesAs: Color.red)
    }

    enum Priority: Int, CaseIterable, Sendable {
      case low = 1
      case medium = 2
      case high = 3
    }

    @Test
    func chunkedIntEnumDecoding() throws {
      let schema = SchemaCoding.Support.schema(
        representing: Priority.self,
        description: nil
      )
      try schema.test(["1"], decodesAs: Priority.low)
    }

  }

}
import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Case Iterable Schema")
struct CaseIterableSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testStringRawValueEnum() throws {
      enum Status: String, CaseIterable {
        case active
        case inactive
        case pending
      }

      let schema = SchemaCoding.Support.schema(representing: Status.self, description: nil)
      try schema.test(.active, isCodedAs: #""active""#)
      try schema.test(.inactive, isCodedAs: #""inactive""#)
      try schema.test(.pending, isCodedAs: #""pending""#)
    }

    @Test
    func testIntRawValueEnum() throws {
      enum Priority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
      }

      let schema = SchemaCoding.Support.schema(representing: Priority.self, description: nil)
      try schema.test(.low, isCodedAs: "1")
      try schema.test(.medium, isCodedAs: "2")
      try schema.test(.high, isCodedAs: "3")
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testStringEnumMetaSchema() throws {
      enum Color: String, CaseIterable {
        case red
        case green
        case blue
      }

      let schema = SchemaCoding.Support.schema(representing: Color.self, description: nil)
      try schema.test(encodesAs: #"{"enum":["red","green","blue"]}"#)
    }

    @Test
    func testIntEnumMetaSchema() throws {
      enum Level: Int, CaseIterable {
        case low = 0
        case high = 1
      }

      let schema = SchemaCoding.Support.schema(representing: Level.self, description: nil)
      try schema.test(encodesAs: #"{"enum":[0,1]}"#)
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      enum Size: String, CaseIterable {
        case small
        case large
      }

      let schema = SchemaCoding.Support.schema(representing: Size.self, description: "Product size")
      try schema.test(encodesAs: #"{"description":"Product size","enum":["small","large"]}"#)
    }

  }

}
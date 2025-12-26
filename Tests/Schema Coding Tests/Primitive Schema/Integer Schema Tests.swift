import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Integer Schema")
struct IntegerSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testIntCoding() throws {
      try test(0 as Int, isCodedAs: "0")
      try test(42 as Int, isCodedAs: "42")
      try test(-100 as Int, isCodedAs: "-100")
      try test(Int.max, isCodedAs: "\(Int.max)")
      try test(Int.min, isCodedAs: "\(Int.min)")
    }

    @Test
    func testInt8Coding() throws {
      try test(0 as Int8, isCodedAs: "0")
      try test(127 as Int8, isCodedAs: "127")
      try test(-128 as Int8, isCodedAs: "-128")
    }

    @Test
    func testInt16Coding() throws {
      try test(0 as Int16, isCodedAs: "0")
      try test(32767 as Int16, isCodedAs: "32767")
      try test(-32768 as Int16, isCodedAs: "-32768")
    }

    @Test
    func testInt32Coding() throws {
      try test(0 as Int32, isCodedAs: "0")
      try test(2147483647 as Int32, isCodedAs: "2147483647")
      try test(-2147483648 as Int32, isCodedAs: "-2147483648")
    }

    @Test
    func testInt64Coding() throws {
      try test(0 as Int64, isCodedAs: "0")
      try test(Int64.max, isCodedAs: "\(Int64.max)")
      try test(Int64.min, isCodedAs: "\(Int64.min)")
    }

    @Test
    func testUIntCoding() throws {
      try test(0 as UInt, isCodedAs: "0")
      try test(42 as UInt, isCodedAs: "42")
      try test(UInt.max, isCodedAs: "\(UInt.max)")
    }

    @Test
    func testUInt8Coding() throws {
      try test(0 as UInt8, isCodedAs: "0")
      try test(255 as UInt8, isCodedAs: "255")
    }

    @Test
    func testUInt16Coding() throws {
      try test(0 as UInt16, isCodedAs: "0")
      try test(65535 as UInt16, isCodedAs: "65535")
    }

    @Test
    func testUInt32Coding() throws {
      try test(0 as UInt32, isCodedAs: "0")
      try test(4294967295 as UInt32, isCodedAs: "4294967295")
    }

    @Test
    func testUInt64Coding() throws {
      try test(0 as UInt64, isCodedAs: "0")
      try test(UInt64.max, isCodedAs: "\(UInt64.max)")
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      try SchemaCoding.Support
        .schema(representing: Int.self)
        .test(
          encodesAs: """
            {
              "type": "integer"
            }
            """
        )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support
        .schema(representing: Int.self, description: "An integer value")
        .test(
          encodesAs: """
            {
              "description": "An integer value",
              "type": "integer"
            }
            """
        )
    }

  }

}

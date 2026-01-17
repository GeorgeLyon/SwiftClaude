import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

import Foundation

@Suite("Number Schema")
struct NumberSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testDoubleCoding() throws {
      try test(0.0 as Double, isCodedAs: "0.0")
      try test(3.14 as Double, isCodedAs: "3.14")
      try test(-2.71828 as Double, isCodedAs: "-2.71828")
      try test(1.5 as Double, isCodedAs: "1.5")
    }

    @Test
    func testFloatCoding() throws {
      try test(Float(0.0), isCodedAs: "0.0")
      try test(Float(3.14), isCodedAs: "3.14")
      try test(Float(-1.5), isCodedAs: "-1.5")
    }

    @Test
    func testFloat16Coding() throws {
      try test(Float16(0.0), isCodedAs: "0.0")
      try test(Float16(1.5), isCodedAs: "1.5")
      try test(Float16(-2.0), isCodedAs: "-2.0")
    }

    @Test
    func testDecimalCoding() throws {
      try test(Decimal(0), isCodedAs: "0")
      try test(Decimal(string: "3.14")!, isCodedAs: "3.14")
      try test(Decimal(string: "-100.5")!, isCodedAs: "-100.5")
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      try SchemaCoding.Support
        .schema(representing: Double.self)
        .test(
          encodesAs: """
            {
              "type": "number"
            }
            """
        )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      try SchemaCoding.Support
        .schema(representing: Double.self, description: "A number value")
        .test(
          encodesAs: """
            {
              "description": "A number value",
              "type": "number"
            }
            """
        )
    }

  }

}
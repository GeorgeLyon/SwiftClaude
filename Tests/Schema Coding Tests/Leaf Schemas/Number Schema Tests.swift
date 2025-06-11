import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Number")
struct NumberSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      SchemaCoding.SchemaCodingSupport.schema(representing: Double.self).schemaJSON == """
        {
          "type": "number"
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      SchemaCoding.SchemaCodingSupport.schema(representing: Double.self).encodedJSON(for: 3.14)
        == """
        3.14
        """
    )
    #expect(
      SchemaCoding.SchemaCodingSupport.schema(representing: Double.self).encodedJSON(for: -2.5)
        == """
        -2.5
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    #expect(
      SchemaCoding.SchemaCodingSupport.schema(representing: Double.self).value(fromJSON: "3.14")
        == 3.14
    )
    #expect(
      SchemaCoding.SchemaCodingSupport.schema(representing: Double.self).value(fromJSON: "-2.5")
        == -2.5
    )
  }

}

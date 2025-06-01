import Testing

@testable import Tool

@Suite("Tuple")
struct TupleSchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      ToolInput.schema(representing: (String, Int).self).schemaJSON == """
        {
          "prefixItems":[
            {
              "type":"string"
            },
            {
              "type":"integer"
            }
          ]
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    let schema1 = ToolInput.schema(representing: (String, Int).self)
    let value1 = schema1.encodedJSON(
      for: schema1.value(
        fromJSON: """
          ["foo", 42]
          """))

    #expect(
      value1 == """
        [
          "foo",
          42
        ]
        """
    )

    let schema2 = ToolInput.schema(representing: (String, Int, Double).self)
    let value2 = schema2.encodedJSON(
      for: schema2.value(
        fromJSON: """
          ["bar", 123, 3.14]
          """))

    #expect(
      value2 == """
        [
          "bar",
          123,
          3.14
        ]
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    let stringIntSchema = ToolInput.schema(representing: (String, Int).self)
    let tuple: (String, Int) = stringIntSchema.value(
      fromJSON: """
        ["hello", 42]
        """)

    #expect(tuple.0 == "hello")
    #expect(tuple.1 == 42)

    let stringIntDoubleSchema = ToolInput.schema(representing: (String, Int, Double).self)
    let tuple3: (String, Int, Double) = stringIntDoubleSchema.value(
      fromJSON: """
        ["world", 123, 3.14]
        """)

    #expect(tuple3.0 == "world")
    #expect(tuple3.1 == 123)
    #expect(tuple3.2 == 3.14)
  }
}

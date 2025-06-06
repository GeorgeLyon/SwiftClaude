import Testing

@testable import SchemaCoding

@Suite("Array Schema")
struct ArraySchemaTests {

  @Test
  private func testSchemaEncoding() throws {
    #expect(
      SchemaSupport.schema(representing: [String].self).schemaJSON == """
        {
          "items": {
            "type": "string"
          }
        }
        """
    )
  }

  @Test
  private func testValueEncoding() throws {
    #expect(
      SchemaSupport.schema(representing: [String].self).encodedJSON(for: ["foo", "bar", "baz"])
        == """
        [
          "foo",
          "bar",
          "baz"
        ]
        """
    )

    #expect(
      SchemaSupport.schema(representing: [Int].self).encodedJSON(for: [1, 2, 3]) == """
        [
          1,
          2,
          3
        ]
        """
    )

    #expect(
      SchemaSupport.schema(representing: [Double].self).encodedJSON(for: []) == """
        [

        ]
        """
    )
  }

  @Test
  private func testValueDecoding() throws {
    let stringSchema = SchemaSupport.schema(representing: [String].self)
    #expect(
      stringSchema.value(
        fromJSON: """
          [
            "foo",
            "bar",
            "baz"
          ]
          """) == ["foo", "bar", "baz"]
    )

    let intSchema = SchemaSupport.schema(representing: [Int].self)
    #expect(
      intSchema.value(
        fromJSON: """
          [
            1,
            2,
            3
          ]
          """) == [1, 2, 3]
    )

    let doubleSchema = SchemaSupport.schema(representing: [Double].self)
    #expect(
      doubleSchema.value(
        fromJSON: """
          [

          ]
          """) == []
    )

    #expect(
      doubleSchema.value(
        fromJSON: """
          [
            1.5,
            2.25,
            3.75
          ]
          """) == [1.5, 2.25, 3.75]
    )
  }

}

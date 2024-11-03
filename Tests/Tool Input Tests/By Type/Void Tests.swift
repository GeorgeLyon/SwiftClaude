import Testing

@testable import ClaudeToolInput

@Suite
struct VoidSchemaTests {

  @Test
  func testVoidSchemaEncoding() async throws {
    let schema = ToolInputVoidSchema()

    #expect(
      try encode(schema) == """
        {
          "additionalProperties" : false,
          "type" : "object"
        }
        """
    )

    #expect(
      try encode(schema) { schema in
        schema.description = "A void schema"
      } == """
        {
          "additionalProperties" : false,
          "description" : "A void schema",
          "type" : "object"
        }
        """
    )
  }

  @Test
  func testVoidSchemaValueEncoding() async throws {
    #expect(
      try encode(VoidWrapper()) == """
        {

        }
        """
    )
  }

  @Test
  func testVoidSchemaValueDecoding() async throws {

    #expect(
      try decode(
        VoidWrapper.self,
        """
        {}
        """
      ) == VoidWrapper()
    )
  }
}

private struct VoidWrapper: ToolInput, Equatable {
  typealias ToolInputSchema = ToolInputVoidSchema
  static var toolInputSchema: ToolInputSchema { ToolInputVoidSchema() }
  init() {}
  init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) {}
  var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue { () }
}

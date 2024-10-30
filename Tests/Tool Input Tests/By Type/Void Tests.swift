/// This file was Claudegenned but required slight adjustments to get working

import XCTest

@testable import ClaudeToolInput

final class VoidSchemaTests: XCTestCase {

  func testVoidSchemaEncoding() async throws {
    let schema = ToolInputVoidSchema()

    XCTAssertEqual(
      try encode(schema),
      """
      {
        "additionalProperties" : false,
        "type" : "object"
      }
      """
    )

    XCTAssertEqual(
      try encode(schema) { schema in
        schema.description = "A void schema"
      },
      """
      {
        "additionalProperties" : false,
        "description" : "A void schema",
        "type" : "object"
      }
      """
    )
  }

  func testVoidSchemaValueEncoding() async throws {
    XCTAssertEqual(
      try encode(VoidWrapper()),
      """
      {

      }
      """
    )
  }

  func testVoidSchemaValueDecoding() async throws {

    XCTAssertEqual(
      try decode(
        VoidWrapper.self,
        """
        {}
        """
      ),
      VoidWrapper()
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

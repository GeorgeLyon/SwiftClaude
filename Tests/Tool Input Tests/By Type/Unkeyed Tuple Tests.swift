import XCTest

@testable import ClaudeToolInput

final class UnkeyedTupleTests: XCTestCase {

  func testUnkeyedTupleSchema() async throws {
    let schema = ToolInputUnkeyedTupleSchema(
      ToolInputBoolSchema(),
      ToolInputStringSchema(),
      ToolInputIntegerSchema<Int>()
    )

    XCTAssertEqual(
      try encode(schema),
      """
      {
        "items" : false,
        "maxItems" : 3,
        "minItems" : 3,
        "prefixItems" : [
          {
            "type" : "boolean"
          },
          {
            "type" : "string"
          },
          {
            "type" : "integer"
          }
        ],
        "type" : "array"
      }
      """
    )

    XCTAssertEqual(
      try encode(schema) { schema in
        schema.description = "A test unkeyed tuple"
      },
      """
      {
        "description" : "A test unkeyed tuple",
        "items" : false,
        "maxItems" : 3,
        "minItems" : 3,
        "prefixItems" : [
          {
            "type" : "boolean"
          },
          {
            "type" : "string"
          },
          {
            "type" : "integer"
          }
        ],
        "type" : "array"
      }
      """
    )
  }

  func testUnkeyedTupleEncoding() async throws {
    let testTuple = TestTuple(toolInputSchemaDescribedValue: (true, "hello", 42))
    XCTAssertEqual(
      try encode(testTuple),
      """
      [
        true,
        "hello",
        42
      ]
      """
    )
  }

  func testUnkeyedTupleDecoding() async throws {
    let decodedTuple = try decode(
      TestTuple.self,
      """
      [
        false,
        "world",
        -10
      ]
      """
    )
    XCTAssertEqual(
      decodedTuple,
      TestTuple(toolInputSchemaDescribedValue: (false, "world", -10))
    )
  }
}

// MARK: - Helper Types

private struct TestTuple: ToolInput, Equatable {
  typealias ToolInputSchema = ToolInputUnkeyedTupleSchema<
    Bool.ToolInputSchema,
    String.ToolInputSchema,
    Int.ToolInputSchema
  >

  static var toolInputSchema: ToolInputSchema {
    ToolInputUnkeyedTupleSchema(
      Bool.toolInputSchema,
      String.toolInputSchema,
      Int.toolInputSchema
    )
  }

  let bool: Bool
  let string: String
  let int: Int

  init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) {
    self.bool = toolInputSchemaDescribedValue.0
    self.string = toolInputSchemaDescribedValue.1
    self.int = toolInputSchemaDescribedValue.2
  }

  var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
    (bool, string, int)
  }
}

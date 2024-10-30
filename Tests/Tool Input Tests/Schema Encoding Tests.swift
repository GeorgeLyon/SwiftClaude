import XCTest

@testable import ClaudeToolInput

final class SchemaEncodingTests: XCTestCase {

  func testBooleanSchema() async throws {
    XCTAssertEqual(
      try encode(ToolInputBoolSchema()),
      """
      {
        "type" : "boolean"
      }
      """
    )
    XCTAssertEqual(
      try encode(ToolInputBoolSchema()) { schema in
        schema.description = .some("To be or not to be?")
      },
      """
      {
        "description" : "To be or not to be?",
        "type" : "boolean"
      }
      """
    )
  }

  func testStringSchema() async throws {
    XCTAssertEqual(
      try encode(ToolInputStringSchema()),
      """
      {
        "type" : "string"
      }
      """
    )
    XCTAssertEqual(
      try encode(ToolInputStringSchema()) { schema in
        schema.description = "A test string"
        schema.minLength = 5
        schema.maxLength = 10
      },
      """
      {
        "description" : "A test string",
        "maxLength" : 10,
        "minLength" : 5,
        "type" : "string"
      }
      """
    )
  }

  func testNumberSchema() async throws {
    XCTAssertEqual(
      try encode(ToolInputNumberSchema<Float>()),
      """
      {
        "type" : "number"
      }
      """
    )
    XCTAssertEqual(
      try encode(ToolInputNumberSchema<Float>()) { schema in
        schema.description = "A test number"
        schema.minimum = 0
        schema.maximum = 100
        schema.exclusiveMinimum = 0
        schema.exclusiveMaximum = 100
        schema.multipleOf = 0.5
      },
      """
      {
        "description" : "A test number",
        "exclusiveMaximum" : 100,
        "exclusiveMinimum" : 0,
        "maximum" : 100,
        "minimum" : 0,
        "multipleOf" : 0.5,
        "type" : "number"
      }
      """
    )
  }

  func testIntegerSchema() async throws {
    XCTAssertEqual(
      try encode(ToolInputIntegerSchema<Int>()),
      """
      {
        "type" : "integer"
      }
      """
    )
    XCTAssertEqual(
      try encode(ToolInputIntegerSchema<Int>()) { schema in
        schema.description = "A test integer"
        schema.minimum = 1
        schema.maximum = 10
        schema.exclusiveMinimum = 0
        schema.exclusiveMaximum = 11
        schema.multipleOf = 2
      },
      """
      {
        "description" : "A test integer",
        "exclusiveMaximum" : 11,
        "exclusiveMinimum" : 0,
        "maximum" : 10,
        "minimum" : 1,
        "multipleOf" : 2,
        "type" : "integer"
      }
      """
    )
  }

  func testArraySchema() async throws {
    XCTAssertEqual(
      try encode(ToolInputArraySchema(element: ToolInputBoolSchema())),
      """
      {
        "items" : {
          "type" : "boolean"
        },
        "type" : "array"
      }
      """
    )
    XCTAssertEqual(
      try encode(ToolInputArraySchema(element: ToolInputBoolSchema())) { schema in
        schema.description = "Binary choice test"
        schema.element.description = "Binary choice answer"
        schema.minItems = 0
        schema.maxItems = 10
        schema.uniqueItems = true
      },
      """
      {
        "description" : "Binary choice test",
        "items" : {
          "description" : "Binary choice answer",
          "type" : "boolean"
        },
        "maxItems" : 10,
        "minItems" : 0,
        "type" : "array",
        "uniqueItems" : true
      }
      """
    )
  }

  func testOptionalSchema() async throws {
    XCTAssertEqual(
      try encode(ToolInputOptionalSchema(wrapped: ToolInputBoolSchema())),
      """
      {
        "type" : [
          "boolean",
          "null"
        ]
      }
      """)
    XCTAssertEqual(
      try encode(ToolInputOptionalSchema(wrapped: ToolInputBoolSchema())) { schema in
        schema.description = .some("This is an optional value.")
      },
      """
      {
        "description" : "This is an optional value.",
        "type" : [
          "boolean",
          "null"
        ]
      }
      """)
    XCTAssertEqual(
      try encode(ToolInputOptionalSchema(wrapped: ToolInputBoolSchema())) { schema in
        schema.wrapped.description = .some("This is the bool value.")
      },
      """
      {
        "anyOf" : [
          {
            "type" : "null"
          },
          {
            "description" : "This is the bool value.",
            "type" : "boolean"
          }
        ]
      }
      """)
    XCTAssertEqual(
      try encode(
        ToolInputOptionalSchema(
          wrapped: ToolInputOptionalSchema(wrapped: ToolInputBoolSchema()))
      ),
      """
      {
        "anyOf" : [
          {
            "type" : "null"
          },
          {
            "properties" : {
              "nestedOptional" : {
                "type" : [
                  "boolean",
                  "null"
                ]
              }
            },
            "type" : "object"
          }
        ]
      }
      """)
  }

  func testKeyedTupleSchema() async throws {
    let baseSchema:
      ToolInputKeyedTupleSchema<
        ToolInputBoolSchema, ToolInputArraySchema<ToolInputBoolSchema>
      >
    baseSchema = ToolInputKeyedTupleSchema.init(
      (key: ToolInputSchemaKey("x"), schema: ToolInputBoolSchema()),
      (key: ToolInputSchemaKey("y"), schema: ToolInputArraySchema(element: ToolInputBoolSchema()))
    )
    XCTAssertEqual(
      try encode(baseSchema),
      """
      {
        "additionalProperties" : false,
        "properties" : {
          "x" : {
            "type" : "boolean"
          },
          "y" : {
            "items" : {
              "type" : "boolean"
            },
            "type" : "array"
          }
        },
        "required" : [
          "x",
          "y"
        ],
        "type" : "object"
      }
      """
    )
    XCTAssertEqual(
      try encode(baseSchema) { schema in
        schema.description = "A test object"
        schema.elements.0.description = .some("A test property")
      },
      """
      {
        "additionalProperties" : false,
        "description" : "A test object",
        "properties" : {
          "x" : {
            "description" : "A test property",
            "type" : "boolean"
          },
          "y" : {
            "items" : {
              "type" : "boolean"
            },
            "type" : "array"
          }
        },
        "required" : [
          "x",
          "y"
        ],
        "type" : "object"
      }
      """
    )
  }

}

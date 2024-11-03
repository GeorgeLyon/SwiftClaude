import Testing

@testable import ClaudeToolInput

@Suite
struct SchemaEncodingTests {

  func testBooleanSchema() async throws {
    #expect(
      try encode(ToolInputBoolSchema()) == """
        {
          "type" : "boolean"
        }
        """
    )
    #expect(
      try encode(ToolInputBoolSchema()) { schema in
        schema.description = .some("To be or not to be?")
      } == """
        {
          "description" : "To be or not to be?",
          "type" : "boolean"
        }
        """
    )
  }

  @Test
  func testStringSchema() async throws {
    #expect(
      try encode(ToolInputStringSchema()) == """
        {
          "type" : "string"
        }
        """
    )
    #expect(
      try encode(ToolInputStringSchema()) { schema in
        schema.description = "A test string"
        schema.minLength = 5
        schema.maxLength = 10
      } == """
        {
          "description" : "A test string",
          "maxLength" : 10,
          "minLength" : 5,
          "type" : "string"
        }
        """
    )
  }

  @Test
  func testNumberSchema() async throws {
    #expect(
      try encode(ToolInputNumberSchema<Float>()) == """
        {
          "type" : "number"
        }
        """
    )
    #expect(
      try encode(ToolInputNumberSchema<Float>()) { schema in
        schema.description = "A test number"
        schema.minimum = 0
        schema.maximum = 100
        schema.exclusiveMinimum = 0
        schema.exclusiveMaximum = 100
        schema.multipleOf = 0.5
      } == """
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

  @Test
  func testIntegerSchema() async throws {
    #expect(
      try encode(ToolInputIntegerSchema<Int>()) == """
        {
          "type" : "integer"
        }
        """
    )
    #expect(
      try encode(ToolInputIntegerSchema<Int>()) { schema in
        schema.description = "A test integer"
        schema.minimum = 1
        schema.maximum = 10
        schema.exclusiveMinimum = 0
        schema.exclusiveMaximum = 11
        schema.multipleOf = 2
      } == """
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

  @Test
  func testArraySchema() async throws {
    #expect(
      try encode(ToolInputArraySchema(element: ToolInputBoolSchema())) == """
        {
          "items" : {
            "type" : "boolean"
          },
          "type" : "array"
        }
        """
    )
    #expect(
      try encode(ToolInputArraySchema(element: ToolInputBoolSchema())) { schema in
        schema.description = "Binary choice test"
        schema.element.description = "Binary choice answer"
        schema.minItems = 0
        schema.maxItems = 10
        schema.uniqueItems = true
      } == """
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

  @Test
  func testOptionalSchema() async throws {
    #expect(
      try encode(ToolInputOptionalSchema(wrapped: ToolInputBoolSchema())) == """
        {
          "type" : [
            "boolean",
            "null"
          ]
        }
        """)
    #expect(
      try encode(ToolInputOptionalSchema(wrapped: ToolInputBoolSchema())) { schema in
        schema.description = .some("This is an optional value.")
      } == """
        {
          "description" : "This is an optional value.",
          "type" : [
            "boolean",
            "null"
          ]
        }
        """)
    #expect(
      try encode(ToolInputOptionalSchema(wrapped: ToolInputBoolSchema())) { schema in
        schema.wrapped.description = .some("This is the bool value.")
      } == """
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
    #expect(
      try encode(
        ToolInputOptionalSchema(
          wrapped: ToolInputOptionalSchema(wrapped: ToolInputBoolSchema()))
      ) == """
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

  @Test
  func testKeyedTupleSchema() async throws {
    let baseSchema:
      ToolInputKeyedTupleSchema<
        ToolInputBoolSchema, ToolInputArraySchema<ToolInputBoolSchema>
      >
    baseSchema = ToolInputKeyedTupleSchema.init(
      (key: ToolInputSchemaKey("x"), schema: ToolInputBoolSchema()),
      (key: ToolInputSchemaKey("y"), schema: ToolInputArraySchema(element: ToolInputBoolSchema()))
    )
    #expect(
      try encode(baseSchema) == """
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
    #expect(
      try encode(baseSchema) { schema in
        schema.description = "A test object"
        schema.elements.0.description = .some("A test property")
      } == """
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

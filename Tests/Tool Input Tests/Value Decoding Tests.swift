import Testing

@testable import ClaudeToolInput

@Suite
struct ValueDecodingTests {

  @Test
  func testBooleanValue() async throws {
    #expect(
      try decode(
        Bool.self,
        """
        true
        """
      ) == true
    )
  }

  @Test
  func testStringValue() async throws {
    #expect(
      try decode(
        String.self,
        """
        "hello"
        """
      ) == "hello"
    )
  }

  @Test
  func testNumberValue() async throws {
    #expect(
      try decode(
        Double.self,
        """
        3.14
        """
      ) == 3.14
    )
  }

  @Test
  func testIntegerValue() async throws {
    #expect(
      try decode(
        Int.self,
        """
        42
        """
      ) == 42
    )
  }

  @Test
  func testArrayValue() async throws {
    #expect(
      try decode(
        [Bool].self,
        """
        [true, false]
        """
      ) == [true, false]
    )
    #expect(
      try decode(
        [Bool].self,
        """
        []
        """
      ) == [Bool]()
    )
  }

  @Test
  func testOptionalValue() async throws {
    #expect(
      try decode(
        Bool?.self,
        """
        null
        """
      ) == Bool?.none
    )
    #expect(
      try decode(
        Bool?.self,
        """
        true
        """
      ) == Bool?.some(true)
    )
    #expect(
      try decode(
        Bool??.self,
        """
        null
        """
      ) == Bool??.none
    )
    #expect(
      try decode(
        Bool??.self,
        """
        {
        }
        """
      ) == Bool??.some(nil)
    )
    #expect(
      try decode(
        Bool??.self,
        """
        {
          "nestedOptional": null
        }
        """
      ) == Bool??.some(nil)
    )
    #expect(
      try decode(
        Bool??.self,
        """
        {
          "nestedOptional": true
        }
        """
      ) == Bool??.some(true)
    )
  }

  @Test
  func testObjectValue() async throws {
    struct Foo: ToolInput, Equatable {
      typealias ToolInputSchema = ToolInputKeyedTupleSchema<
        Bool.ToolInputSchema,
        [Bool].ToolInputSchema
      >
      static var toolInputSchema: ToolInputSchema {
        ToolInputKeyedTupleSchema(
          (ToolInputSchemaKey("x"), Bool.toolInputSchema),
          (ToolInputSchemaKey("y"), [Bool].toolInputSchema)
        )
      }
      init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) throws {
        x = try Bool(toolInputSchemaDescribedValue: toolInputSchemaDescribedValue.0)
        y = try [Bool](toolInputSchemaDescribedValue: toolInputSchemaDescribedValue.1)
      }
      var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
        (x, y)
      }
      init(x: Bool, y: [Bool]) {
        self.x = x
        self.y = y
      }
      let x: Bool
      let y: [Bool]
    }
    #expect(
      try decode(
        Foo.self,
        """
        {
          "x": true,
          "y": [true, false]
        }
        """) == Foo(x: true, y: [true, false])
    )

    struct Bar: ToolInput, Equatable {
      typealias ToolInputSchema = ToolInputKeyedTupleSchema<
        Foo.ToolInputSchema
      >
      static var toolInputSchema: ToolInputSchema {
        ToolInputKeyedTupleSchema(
          (ToolInputSchemaKey("foo"), Foo.toolInputSchema)
        )
      }
      init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) throws {
        foo = try Foo(
          toolInputSchemaDescribedValue: toolInputSchemaDescribedValue
        )
      }
      var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
        foo.toolInputSchemaDescribedValue
      }
      init(foo: Foo) {
        self.foo = foo
      }
      let foo: Foo
    }

    #expect(
      try decode(
        Bar.self,
        """
        {
          "foo": {
            "x": true,
            "y": [true, false]
          }
        }
        """) == Bar(foo: Foo(x: true, y: [true, false]))
    )
  }
}

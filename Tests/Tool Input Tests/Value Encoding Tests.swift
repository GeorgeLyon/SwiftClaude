import Testing

@testable import ClaudeToolInput

@Suite
struct ValueEncodingTests {

  @Test
  func testBooleanValue() throws {
    #expect(
      try encode(true) == """
        true
        """
    )
    #expect(
      try encode(false) == """
        false
        """
    )
  }

  func testStringValue() throws {
    #expect(
      try encode("hello") == """
        "hello"
        """
    )
    #expect(
      try encode("") == """
        ""
        """
    )
  }

  @Test
  func testNumberValue() throws {
    #expect(
      try encode(3.14 as Float) == """
        3.14
        """
    )
    #expect(
      try encode(3.14159265359 as Double) == """
        3.14159265359
        """
    )
  }

  @Test
  func testIntegerValue() throws {
    #expect(
      try encode(42 as Int) == """
        42
        """
    )
    #expect(
      try encode(-100 as Int) == """
        -100
        """
    )
  }

  @Test
  func testArrayValue() throws {
    #expect(
      try encode([true, false] as [Bool]) == """
        [
          true,
          false
        ]
        """
    )
    #expect(
      try encode([] as [Bool]) == """
        [

        ]
        """
    )
    #expect(
      try encode(["a", "b", "c"] as [String]) == """
        [
          "a",
          "b",
          "c"
        ]
        """
    )
  }

  @Test
  func testOptionalValue() throws {
    #expect(
      try encode(Bool?.none) == """
        null
        """
    )
    #expect(
      try encode(Bool?.some(true)) == """
        true
        """
    )
    #expect(
      try encode(Bool??.none) == """
        null
        """
    )
    #expect(
      try encode(Bool??.some(nil)) == """
        {
          "nestedOptional" : null
        }
        """
    )
    #expect(
      try encode(Bool??.some(true)) == """
        {
          "nestedOptional" : true
        }
        """
    )
  }

  @Test
  func testObjectValue() throws {
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
      init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) {
        x = toolInputSchemaDescribedValue.0
        y = toolInputSchemaDescribedValue.1
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
      try encode(Foo(x: true, y: [true, false])) == """
        {
          "x" : true,
          "y" : [
            true,
            false
          ]
        }
        """
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
      var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
        foo.toolInputSchemaDescribedValue
      }
      init(toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue) {
        foo = Foo(toolInputSchemaDescribedValue: toolInputSchemaDescribedValue)
      }
      init(foo: Foo) {
        self.foo = foo
      }
      let foo: Foo
    }

    #expect(
      try encode(Bar(foo: Foo(x: true, y: [true, false]))) == """
        {
          "foo" : {
            "x" : true,
            "y" : [
              true,
              false
            ]
          }
        }
        """
    )
  }
}

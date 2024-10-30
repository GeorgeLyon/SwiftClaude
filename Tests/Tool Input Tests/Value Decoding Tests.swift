import XCTest

@testable import ClaudeToolInput

final class ValueDecodingTests: XCTestCase {

  func testBooleanValue() async throws {
    XCTAssertEqual(
      try decode(
        Bool.self,
        """
        true
        """
      ),
      true
    )
  }

  func testStringValue() async throws {
    XCTAssertEqual(
      try decode(
        String.self,
        """
        "hello"
        """
      ),
      "hello"
    )
  }

  func testNumberValue() async throws {
    XCTAssertEqual(
      try decode(
        Double.self,
        """
        3.14
        """
      ),
      3.14
    )
  }

  func testIntegerValue() async throws {
    XCTAssertEqual(
      try decode(
        Int.self,
        """
        42
        """
      ),
      42
    )
  }

  func testArrayValue() async throws {
    XCTAssertEqual(
      try decode(
        [Bool].self,
        """
        [true, false]
        """
      ),
      [true, false]
    )
    XCTAssertEqual(
      try decode(
        [Bool].self,
        """
        []
        """
      ),
      [Bool]()
    )
  }

  func testOptionalValue() async throws {
    XCTAssertEqual(
      try decode(
        Bool?.self,
        """
        null
        """
      ),
      Bool?.none
    )
    XCTAssertEqual(
      try decode(
        Bool?.self,
        """
        true
        """
      ),
      Bool?.some(true)
    )
    XCTAssertEqual(
      try decode(
        Bool??.self,
        """
        null
        """
      ),
      Bool??.none
    )
    XCTAssertEqual(
      try decode(
        Bool??.self,
        """
        {
        }
        """
      ),
      Bool??.some(nil)
    )
    XCTAssertEqual(
      try decode(
        Bool??.self,
        """
        {
          "nestedOptional": null
        }
        """
      ),
      Bool??.some(nil)
    )
    XCTAssertEqual(
      try decode(
        Bool??.self,
        """
        {
          "nestedOptional": true
        }
        """
      ),
      Bool??.some(true)
    )
  }

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
    XCTAssertEqual(
      try decode(
        Foo.self,
        """
        {
          "x": true,
          "y": [true, false]
        }
        """),
      Foo(x: true, y: [true, false])
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

    XCTAssertEqual(
      try decode(
        Bar.self,
        """
        {
          "foo": {
            "x": true,
            "y": [true, false]
          }
        }
        """),
      Bar(foo: Foo(x: true, y: [true, false]))
    )
  }
}

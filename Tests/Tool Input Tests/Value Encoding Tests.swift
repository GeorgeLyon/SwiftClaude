import XCTest

@testable import ClaudeToolInput

final class ValueEncodingTests: XCTestCase {

  func testBooleanValue() throws {
    XCTAssertEqual(
      try encode(true),
      """
      true
      """
    )
    XCTAssertEqual(
      try encode(false),
      """
      false
      """
    )
  }

  func testStringValue() throws {
    XCTAssertEqual(
      try encode("hello"),
      """
      "hello"
      """
    )
    XCTAssertEqual(
      try encode(""),
      """
      ""
      """
    )
  }

  func testNumberValue() throws {
    XCTAssertEqual(
      try encode(3.14 as Float),
      """
      3.14
      """
    )
    XCTAssertEqual(
      try encode(3.14159265359 as Double),
      """
      3.14159265359
      """
    )
  }

  func testIntegerValue() throws {
    XCTAssertEqual(
      try encode(42 as Int),
      """
      42
      """
    )
    XCTAssertEqual(
      try encode(-100 as Int),
      """
      -100
      """
    )
  }

  func testArrayValue() throws {
    XCTAssertEqual(
      try encode([true, false] as [Bool]),
      """
      [
        true,
        false
      ]
      """
    )
    XCTAssertEqual(
      try encode([] as [Bool]),
      """
      [

      ]
      """
    )
    XCTAssertEqual(
      try encode(["a", "b", "c"] as [String]),
      """
      [
        "a",
        "b",
        "c"
      ]
      """
    )
  }

  func testOptionalValue() throws {
    XCTAssertEqual(
      try encode(Bool?.none),
      """
      null
      """
    )
    XCTAssertEqual(
      try encode(Bool?.some(true)),
      """
      true
      """
    )
    XCTAssertEqual(
      try encode(Bool??.none),
      """
      null
      """
    )
    XCTAssertEqual(
      try encode(Bool??.some(nil)),
      """
      {
        "nestedOptional" : null
      }
      """
    )
    XCTAssertEqual(
      try encode(Bool??.some(true)),
      """
      {
        "nestedOptional" : true
      }
      """
    )
  }

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

    XCTAssertEqual(
      try encode(Foo(x: true, y: [true, false])),
      """
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

    XCTAssertEqual(
      try encode(Bar(foo: Foo(x: true, y: [true, false]))),
      """
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

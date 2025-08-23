import SchemaCodingTestSupport
import Testing

@testable import JSONSupport
@testable import SchemaCoding

@Suite("Tuple")
struct TupleSchemaTests {

  @Test
  private func testTupleEncoding() throws {
    // Single element tuple
    let singleSchema = SchemaCoding.Support.tupleSchema {
      SchemaCoding.Support.schema(representing: String.self)
    }
    try singleSchema.test(("hello"), isCodedAs: "[\"hello\"]")

    // Two element tuple
    let twoSchema = SchemaCoding.Support.tupleSchema {
      SchemaCoding.Support.schema(representing: String.self)
      SchemaCoding.Support.schema(representing: Int.self)
    }
    try twoSchema.test(("foo", 42), isCodedAs: "[\"foo\",42]")

    // Three element tuple
    let threeSchema = SchemaCoding.Support.tupleSchema {
      SchemaCoding.Support.schema(representing: String.self)
      SchemaCoding.Support.schema(representing: Int.self)
      SchemaCoding.Support.schema(representing: Bool.self)
    }
    try threeSchema.test(("test", 123, true), isCodedAs: "[\"test\",123,true]")
  }

  @Test
  private func testOptionalElementsInTuple() throws {
    // Since Optional conforms to SchemaCodable, we can use the optional schema directly
    let optStringSchema = Optional<String>.schema
    let optIntSchema = Optional<Int>.schema
    let optBoolSchema = Optional<Bool>.schema

    let schema = SchemaCoding.Support.tupleSchema {
      optStringSchema
      optIntSchema
      optBoolSchema
    }

    // All nil
    try schema.test((nil as String?, nil as Int?, nil as Bool?), isCodedAs: "[null,null,null]")

    // Mixed values
    try schema.test(
      ("hello" as String?, 42 as Int?, nil as Bool?), isCodedAs: "[\"hello\",42,null]")

    // All values
    try schema.test(
      ("world" as String?, 100 as Int?, true as Bool?), isCodedAs: "[\"world\",100,true]")
  }

  @Test
  private func testNestedTupleInTuple() throws {
    // Nested tuples aren't directly testable with Schema.test due to inner tuple not being Equatable
    // Test encoding manually
    let innerSchema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Bool.self)
    )
    let outerSchema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: String.self),
      innerSchema
    )

    var encoder = SchemaCoding.Support.Encoder()
    outerSchema.encode(("outer", (42, true)), to: &encoder)
    #expect(encoder.stream.stringRepresentation == "[\"outer\",[42,true]]")

    encoder = SchemaCoding.Support.Encoder()
    outerSchema.encode(("test", (0, false)), to: &encoder)
    #expect(encoder.stream.stringRepresentation == "[\"test\",[0,false]]")
  }

  @Test
  private func testLargeTuple() throws {
    let schema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self)
    )

    try schema.test((1, 2, 3, 4, 5, 6, 7, 8), isCodedAs: "[1,2,3,4,5,6,7,8]")
    try schema.test((10, 20, 30, 40, 50, 60, 70, 80), isCodedAs: "[10,20,30,40,50,60,70,80]")
  }

  @Test
  private func testMixedTypesTuple() throws {
    let schema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: String.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Double.self),
      SchemaCoding.Support.schema(representing: Bool.self)
    )

    try schema.test(("test", 42, 3.14, true), isCodedAs: "[\"test\",42,3.14,true]")
    try schema.test(("", -1, -2.5, false), isCodedAs: "[\"\",-1,-2.5,false]")
    try schema.test(("mixed", 0, 0.0, true), isCodedAs: "[\"mixed\",0,0.0,true]")
  }

  @Test
  private func testFloatingPointPrecision() throws {
    let schema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: Float.self),
      SchemaCoding.Support.schema(representing: Double.self)
    )

    try schema.test((Float(3.14), 2.71828), isCodedAs: "[3.14,2.71828]")
    try schema.test((Float(0.0), 0.0), isCodedAs: "[0.0,0.0]")
    try schema.test((Float(-1.5), -999.999), isCodedAs: "[-1.5,-999.999]")
  }

  @Test
  private func testSpecialCharactersInStrings() throws {
    let schema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: String.self),
      SchemaCoding.Support.schema(representing: String.self)
    )

    try schema.test(
      ("hello\nworld", "tab\there"), isCodedAs: "[\"hello\\nworld\",\"tab\\there\"]")
    try schema.test(
      ("quote\"here", "backslash\\test"), isCodedAs: "[\"quote\\\"here\",\"backslash\\\\test\"]")
    try schema.test(("unicode: 👍", "emoji: 🎉"), isCodedAs: "[\"unicode: 👍\",\"emoji: 🎉\"]")
  }

  @Test
  private func testHomogeneousTuple() throws {
    let schema = SchemaCoding.Support.tupleSchema(
      elements:
        SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self),
      SchemaCoding.Support.schema(representing: Int.self)
    )

    try schema.test((1, 2, 3), isCodedAs: "[1,2,3]")
    try schema.test((42, 0, -17), isCodedAs: "[42,0,-17]")
    try schema.test((999, 999, 999), isCodedAs: "[999,999,999]")
  }

}

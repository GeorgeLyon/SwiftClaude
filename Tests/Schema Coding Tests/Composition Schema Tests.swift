import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Composition Schema")
struct CompositionSchemaTests {

  @Suite("Array Compositions")
  struct ArrayCompositionTests {

    @Test
    func testArrayOfArrays() throws {
      let innerSchema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      let schema = SchemaCoding.Support.ArraySchema(
        elementSchema: innerSchema
      )

      try schema.test([[true, false], [false]], isCodedAs: "[[true,false],[false]]")
      try schema.test([[]], isCodedAs: "[[]]")
      try schema.test([], isCodedAs: "[]")
    }

    @Test
    func testArrayOfOptionals() throws {
      let schema = SchemaCoding.Support.ArraySchema(
        elementSchema: Bool?.schema
      )

      try schema.test([true, nil, false], isCodedAs: #"[{"value":true},{},{"value":false}]"#)
      try schema.test([nil, nil], isCodedAs: #"[{},{}]"#)
    }

  }

  @Suite("Tuple Compositions")
  struct TupleCompositionTests {

    @Test
    func testTupleOfArrays() throws {
      let arraySchema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          arraySchema,
          arraySchema
      )

      try schema.test(
        ([true], [false, true]),
        flatten: { ($0.0, $0.1) },
        isCodedAs: "[[true],[false,true]]"
      )
    }

    @Test
    func testTupleOfTuples() throws {
      let innerSchema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.BooleanSchema(),
          SchemaCoding.Support.BooleanSchema()
      )
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          innerSchema,
          innerSchema
      )

      try schema.test(
        ((true, false), (false, true)),
        flatten: { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) },
        isCodedAs: "[[true,false],[false,true]]"
      )
    }

    @Test
    func testTupleOfOptionals() throws {
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          Bool?.schema,
          Bool?.schema
      )

      try schema.test(
        (true, nil),
        flatten: { ($0.0, $0.1) },
        isCodedAs: #"[{"value":true},{}]"#
      )
    }

  }

  @Suite("Optional Compositions")
  struct OptionalCompositionTests {

    @Test
    func testOptionalOfOptional() throws {
      // Testing Bool?? - deeply nested optionals
      let schema = Bool??.schema

      // .some(.some(true))
      try schema.test(.some(.some(true)), isCodedAs: #"{"value":{"value":true}}"#)

      // .some(.none)
      try schema.test(.some(.none), isCodedAs: #"{"value":{}}"#)

      // .none
      try schema.test(Bool??.none, isCodedAs: "{}")
    }

    @Test
    func testOptionalOfArray() throws {
      let arraySchema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      let schema = SchemaCoding.Support.OptionalSchema(
        wrappedSchema: arraySchema
      )

      try schema.test([true, false], isCodedAs: #"{"value":[true,false]}"#)
      try schema.test(nil, isCodedAs: "{}")
    }

  }

  @Suite("Mixed Compositions")
  struct MixedCompositionTests {

    @Test
    func testArrayOfArrayOfArrays() throws {
      let innerSchema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      let middleSchema = SchemaCoding.Support.ArraySchema(
        elementSchema: innerSchema
      )
      let schema = SchemaCoding.Support.ArraySchema(
        elementSchema: middleSchema
      )

      try schema.test([[[true]]], isCodedAs: "[[[true]]]")
      try schema.test([[[], [true, false]], [[false]]], isCodedAs: "[[[],[true,false]],[[false]]]")
    }

    @Test
    func testTupleOfMixedTypes() throws {
      let arraySchema = SchemaCoding.Support.ArraySchema(
        elementSchema: SchemaCoding.Support.BooleanSchema()
      )
      let schema = SchemaCoding.Support.TupleSchema(
        elementSchemas:
          SchemaCoding.Support.BooleanSchema(),
          arraySchema,
          SchemaCoding.Support.schema(representing: String.self)
      )

      try schema.test(
        (true, [false, true], "test"),
        flatten: { ($0.0, $0.1, $0.2) },
        isCodedAs: #"[true,[false,true],"test"]"#
      )
    }

  }

}
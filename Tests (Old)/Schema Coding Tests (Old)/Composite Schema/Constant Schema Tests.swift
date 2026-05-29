import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Constant Schema")
struct ConstantSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testConstantStringValue() throws {
      let schema = SchemaCoding.Support.ConstantSchema(
        wrappedSchema: SchemaCoding.Support.schema(representing: String.self),
        constantValue: "fixed"
      )
      // Encoding always produces the constant value
      try schema.test((), encodesAs: #""fixed""#)
    }

    @Test
    func testConstantIntegerValue() throws {
      let schema = SchemaCoding.Support.ConstantSchema(
        wrappedSchema: SchemaCoding.Support.schema(representing: Int.self),
        constantValue: 42
      )
      try schema.test((), encodesAs: "42")
    }

    @Test
    func testConstantBooleanValue() throws {
      let schema = SchemaCoding.Support.ConstantSchema(
        wrappedSchema: SchemaCoding.Support.BooleanSchema(),
        constantValue: true
      )
      try schema.test((), encodesAs: "true")
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testMetaSchemaWithoutDescription() throws {
      let schema = SchemaCoding.Support.ConstantSchema(
        wrappedSchema: SchemaCoding.Support.schema(representing: String.self),
        constantValue: "constant"
      )
      try schema.test(
        encodesAs: """
          {
            "const": "constant"
          }
          """
      )
    }

    @Test
    func testMetaSchemaWithDescription() throws {
      let schema = SchemaCoding.Support.ConstantSchema(
        description: "A constant value",
        wrappedSchema: SchemaCoding.Support.schema(representing: Int.self),
        constantValue: 100
      )
      try schema.test(
        encodesAs: """
          {
            "description": "A constant value",
            "const": 100
          }
          """
      )
    }

  }

}
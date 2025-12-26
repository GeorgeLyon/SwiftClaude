import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Object Schema")
struct ObjectSchemaTests {

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testConcreteObjectSchema() throws {
      // Test basic object with required and optional properties
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "required",
          schema: SchemaCoding.Support.BooleanSchema()
        )
        SchemaCoding.Support.OptionalObjectProperty(
          name: "optional",
          schema: SchemaCoding.Support.OptionalSchema(
            wrappedSchema: SchemaCoding.Support.schema(representing: Int.self)
          )
        )
      }

      // With both values
      try objectSchema.test((true, 42 as Int?), isCodedAs: #"{"required":true,"optional":42}"#)

      // With nil optional (property omitted)
      try objectSchema.test((false, nil as Int?), isCodedAs: #"{"required":false}"#)
    }

    @Test
    func testDirectObjectProperty() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "name",
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }

      try objectSchema.test("hello", isCodedAs: #"{"name":"hello"}"#)
    }

    @Test
    func testOptionalObjectProperty() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.OptionalObjectProperty(
          name: "value",
          schema: SchemaCoding.Support.OptionalSchema(
            wrappedSchema: SchemaCoding.Support.BooleanSchema()
          )
        )
      }

      try objectSchema.test(true as Bool?, isCodedAs: #"{"value":true}"#)
      try objectSchema.test(nil as Bool?, isCodedAs: "{}")
    }

    @Test
    func testConstantOptionalObjectProperty() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "version",
          constantOptionalSchema: SchemaCoding.Support.ConstantSchema(
            wrappedSchema: SchemaCoding.Support.OptionalSchema(
              wrappedSchema: SchemaCoding.Support.schema(representing: String.self)
            ),
            constantValue: "1.0"
          )
        )
      }

      try objectSchema.test((), isCodedAs: #"{"version":"1.0"}"#)
    }

    @Test
    func testConstantOptionalObjectPropertyWithNilValue() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "version",
          constantOptionalSchema: SchemaCoding.Support.ConstantSchema(
            wrappedSchema: SchemaCoding.Support.OptionalSchema(
              wrappedSchema: SchemaCoding.Support.schema(representing: String.self)
            ),
            constantValue: nil
          )
        )
      }

      try objectSchema.test((), isCodedAs: "{}")
    }

    @Test
    func testObjectSchemaWithWrapper() throws {
      struct Point: Equatable {
        let x: Int
        let y: Int
      }

      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "x",
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
        SchemaCoding.Support.DirectObjectProperty(
          name: "y",
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
      }

      let schema = objectSchema.wrap { (x, y) in
        Point(x: x, y: y)
      } unwrap: { point in
        (point.x, point.y)
      }

      try schema.test(Point(x: 10, y: 20), isCodedAs: #"{"x":10,"y":20}"#)
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testObjectMetaSchema() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema(
        description: "A test object"
      ) {
        SchemaCoding.Support.DirectObjectProperty(
          name: "id",
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
        SchemaCoding.Support.OptionalObjectProperty(
          name: "name",
          schema: SchemaCoding.Support.OptionalSchema(
            wrappedSchema: SchemaCoding.Support.schema(representing: String.self)
          )
        )
      }

      try objectSchema.test(
        encodesAs:
          #"{"description":"A test object","properties":{"id":{"type":"integer"},"name":{"type":"string"}},"required":["id"]}"#
      )
    }

    @Test
    func testObjectMetaSchemaWithPropertyDescriptions() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "count",
          description: "The number of items",
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
      }

      try objectSchema.test(
        encodesAs:
          #"{"properties":{"count":{"description":"The number of items","type":"integer"}},"required":["count"]}"#
      )
    }

    @Test
    func testConstantOptionalObjectPropertyMetaSchema() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "version",
          constantOptionalSchema: SchemaCoding.Support.ConstantSchema(
            wrappedSchema: SchemaCoding.Support.OptionalSchema(
              wrappedSchema: SchemaCoding.Support.schema(representing: String.self)
            ),
            constantValue: "1.0"
          )
        )
      }

      try objectSchema.test(
        encodesAs: #"{"properties":{"version":{"const":"1.0"}},"required":["version"]}"#
      )
    }

    @Test
    func testConstantOptionalObjectPropertyWithNilValueMetaSchema() throws {
      let objectSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.DirectObjectProperty(
          name: "version",
          constantOptionalSchema: SchemaCoding.Support.ConstantSchema(
            wrappedSchema: SchemaCoding.Support.OptionalSchema(
              wrappedSchema: SchemaCoding.Support.schema(representing: String.self)
            ),
            constantValue: nil
          )
        )
      }

      try objectSchema.test(
        encodesAs: #"{"properties":{}}"#
      )
    }

  }

}

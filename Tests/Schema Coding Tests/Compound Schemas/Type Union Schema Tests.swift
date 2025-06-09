import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

private enum TypeUnion {
  case string(String)
  case array([Int])

  static var schema: some SchemaCoding.Schema<TypeUnion> {
    SchemaCoding.SchemaResolver.typeUnionSchema(
      representing: TypeUnion.self,
      null: SchemaCoding.SchemaResolver.typeUnionSchemaUnhandledCase(),
      boolean: SchemaCoding.SchemaResolver.typeUnionSchemaUnhandledCase(),
      number: SchemaCoding.SchemaResolver.typeUnionSchemaUnhandledCase(),
      string: .init(
        schema: SchemaCoding.SchemaResolver.schema(representing: String.self),
        initializer: { .string($0) }
      ),
      array: SchemaCoding.SchemaResolver.typeUnionSchemaUnhandledCase(),
      object: SchemaCoding.SchemaResolver.typeUnionSchemaUnhandledCase(),
      caseEncoder: { value, null, boolean, number, string, array, object in
        fatalError()
      }
    )
  }
}

@Suite("Type Union Schema Tests")
struct TypeUnionSchemaTests {

  @Test
  func testTypeUnionSchema() throws {

    #expect(
      TypeUnion.schema.schemaJSON == """
        {
          "oneOf": [
            {
              "type": "string"
            }
          ]
        }
        """
    )

  }

}

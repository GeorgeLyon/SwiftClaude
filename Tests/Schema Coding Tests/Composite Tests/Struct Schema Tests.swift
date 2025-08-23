import SchemaCodingTestSupport
import Testing

@testable import JSONSupport
@testable import SchemaCoding

@SchemaCodable(
  description: "A test struct",
  codingKeyConversionStrategy: .convertToSnakeCase
)
private struct TestStruct: Equatable {
  let property: String

  @SchemaDetails(description: "An optional property")
  let optionalProperty: Int?
}

@Suite("Struct")
struct StructSchemaTests {

  @Test
  func structTest() throws {
    try test(
      TestStruct(property: "Hello", optionalProperty: 42),
      isCodedAs: #"{"property":"Hello","optional_property":42}"#
    )
    try test(
      TestStruct(property: "Hello", optionalProperty: nil),
      isCodedAs: #"{"property":"Hello"}"#
    )
  }

  @Test
  func schemaTest() throws {
    try TestStruct.schema.test(
      encodesAs: """
        {
          "description": "A test struct",
          "properties": {
            "property": {
              "type": "string"
            },
            "optional_property": {
              "description": "An optional property",
              "type": "integer"
            }
          },
          "required": [
            "property"
          ]
        }
        """,
      prettyPrint: true
    )
  }

}

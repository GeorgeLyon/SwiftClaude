import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Schema Coding")
struct SchemaCodingTests {

  @Test
  func stringCoding() throws {
    try test("hello", isCodedAs: "\"hello\"")
  }

  @Test
  func objectWithStringPropertyCoding() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self
    ) {
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
    }
    try schema.test(("Alice"), isCodedAs: "{\"name\":\"Alice\"}")
  }

  @Test
  func metaMetaMetaSchemaEncoding() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self
    ) {
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
    }
    let context = SchemaCoding.Support.SchemaContext()
    let metaSchema = schema.metaSchema(in: context)
    let metaMetaSchema = metaSchema.metaSchema(in: context)
    let metaMetaMetaSchema = metaMetaSchema.metaSchema(in: context)

    try metaSchema.test(
      schema,
      encodesAs: """
        {
          "properties": {
            "name": {
              "type": "string"
            }
          }
        }
        """,
      prettyPrint: true
    )
    try metaMetaSchema.test(
      metaSchema,
      encodesAs: """
        {
          "properties": {
            "description": {
              "type": "string"
            },
            "properties": {
              "name": {
                "properties": {
                  "description": {
                    "type": "string"
                  },
                  "type": {
                    "const": "string"
                  }
                }
              }
            }
          }
        }
        """,
      prettyPrint: true
    )
    try metaMetaMetaSchema.test(
      metaMetaSchema,
      encodesAs: """
        {
          "properties": {
            "description": {
              "type": "string"
            },
            "properties": {
              "description": {
                "properties": {
                  "description": {
                    "type": "string"
                  },
                  "type": {
                    "const": "string"
                  }
                }
              },
              "properties": {
                "name": {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "properties": {
                      "description": {
                        "properties": {
                          "description": {
                            "type": "string"
                          },
                          "type": {
                            "const": "string"
                          }
                        }
                      },
                      "type": {
                        "properties": {
                          "description": {
                            "type": "string"
                          },
                          "const": {
                            "type": "string"
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """,
      prettyPrint: true
    )
  }

}

private enum CodingKeys: String, CodingKey {
  case name
}

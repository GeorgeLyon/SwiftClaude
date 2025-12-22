import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Object Schema")
struct ObjectSchemaTests {

  @Test
  func objectWithStringPropertyCoding() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.RequiredObjectProperty(
        name: "name",
        schema: String.schema
      )
    }
    try schema.test(("Alice"), isCodedAs: "{\"name\":\"Alice\"}")
  }

  @Test
  func metaMetaMetaSchemaEncoding() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.RequiredObjectProperty(
        name: "name",
        schema: String.schema
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
          },
          "required": [
            "name"
          ]
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
              "properties": {
                "name": {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "type": {
                      "const": "string"
                    }
                  },
                  "required": [
                    "type"
                  ]
                }
              },
              "required": [
                "name"
              ]
            },
            "required": {
              "const": [
                "name"
              ]
            }
          },
          "required": [
            "properties",
            "required"
          ]
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
              "properties": {
                "description": {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "type": {
                      "const": "string"
                    }
                  },
                  "required": [
                    "type"
                  ]
                },
                "properties": {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "properties": {
                      "properties": {
                        "name": {
                          "properties": {
                            "description": {
                              "type": "string"
                            },
                            "properties": {
                              "properties": {
                                "description": {
                                  "properties": {
                                    "description": {
                                      "type": "string"
                                    },
                                    "type": {
                                      "const": "string"
                                    }
                                  },
                                  "required": [
                                    "type"
                                  ]
                                },
                                "type": {
                                  "properties": {
                                    "description": {
                                      "type": "string"
                                    },
                                    "const": {
                                      "type": "string"
                                    }
                                  },
                                  "required": [
                                    "const"
                                  ]
                                }
                              },
                              "required": [
                                "description",
                                "type"
                              ]
                            },
                            "required": {
                              "const": [
                                "type"
                              ]
                            }
                          },
                          "required": [
                            "properties",
                            "required"
                          ]
                        }
                      },
                      "required": [
                        "name"
                      ]
                    },
                    "required": {
                      "const": [
                        "name"
                      ]
                    }
                  },
                  "required": [
                    "properties",
                    "required"
                  ]
                },
                "required": {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "const": {
                      "items": {
                        "type": "string"
                      }
                    }
                  },
                  "required": [
                    "const"
                  ]
                }
              },
              "required": [
                "description",
                "properties",
                "required"
              ]
            },
            "required": {
              "const": [
                "properties",
                "required"
              ]
            }
          },
          "required": [
            "properties",
            "required"
          ]
        }
        """,
      prettyPrint: true
    )
  }

}

@Suite("Optional Object Properties")
struct OptionalObjectPropertyTests {

  @Test
  func optionalPropertyWithValue() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.OptionalObjectProperty(
        name: "nickname",
        schema: String.schema
      )
    }
    try schema.test(("Bob"), isCodedAs: "{\"nickname\":\"Bob\"}")
  }

  @Test
  func optionalPropertyWithNil() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.OptionalObjectProperty(
        name: "nickname",
        schema: String.schema
      )
    }
    try schema.test((nil as String?), isCodedAs: "{}")
  }

  @Test
  func optionalPropertyDecoding() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.OptionalObjectProperty(
        name: "nickname",
        schema: String.schema
      )
    }
    try schema.test("{\"nickname\":\"Alice\"}", decodesAs: ("Alice" as String?))
  }

  @Test
  func optionalPropertyMissing() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.OptionalObjectProperty(
        name: "nickname",
        schema: String.schema
      )
    }
    try schema.test("{}", decodesAs: (nil as String?))
  }

  @Test
  func mixedRequiredAndOptionalProperties() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.RequiredObjectProperty(
        name: "name",
        schema: String.schema
      )
      SchemaCoding.Support.OptionalObjectProperty(
        name: "nickname",
        schema: String.schema
      )
    }
    try schema.test(("Alice", "Ali"), isCodedAs: "{\"name\":\"Alice\",\"nickname\":\"Ali\"}")
    try schema.test(("Bob", nil), isCodedAs: "{\"name\":\"Bob\"}")
  }

  @Test
  func mixedRequiredAndOptionalPropertiesDecoding() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.RequiredObjectProperty(
        name: "name",
        schema: String.schema
      )
      SchemaCoding.Support.OptionalObjectProperty(
        name: "nickname",
        schema: String.schema
      )
    }
    try schema.test(
      "{\"name\":\"Alice\",\"nickname\":\"Ali\"}", decodesAs: ("Alice", "Ali" as String?))
    try schema.test("{\"name\":\"Bob\"}", decodesAs: ("Bob", nil as String?))
  }

  @Test
  func optionalPropertyMetaSchema() throws {
    let schema = SchemaCoding.Support.ConcreteObjectSchema {
      SchemaCoding.Support.RequiredObjectProperty(
        name: "name",
        schema: String.schema
      )
      SchemaCoding.Support.OptionalObjectProperty(
        name: "nickname",
        schema: String.schema
      )
    }
    let context = SchemaCoding.Support.SchemaContext()
    let metaSchema = schema.metaSchema(in: context)

    try metaSchema.test(
      schema,
      encodesAs: """
        {
          "properties": {
            "name": {
              "type": "string"
            },
            "nickname": {
              "type": "string"
            }
          },
          "required": [
            "name"
          ]
        }
        """,
      prettyPrint: true
    )
  }

}

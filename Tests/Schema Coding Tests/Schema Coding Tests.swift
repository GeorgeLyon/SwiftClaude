import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Schema Coding")
struct SchemaCodingTests {

  @Test
  func stringCoding() throws {
    try test("hello", isCodedAs: "\"hello\"")
  }

  // MARK: - Object Schema

  @Suite("Object Schema")
  struct ObjectSchema {

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

  // MARK: - Composite Object Schema

  @Suite("Composite Object Schema")
  struct CompositeObjectSchema {

    @Test
    func compositeObjectWithTwoStringPropertiesCoding() throws {
      let schema1 = SchemaCoding.Support.objectSchema(
        propertyName: CodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let schema2 = SchemaCoding.Support.objectSchema(
        propertyName: AgeCodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: AgeCodingKeys.age,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let compositeSchema = SchemaCoding.Support.CompositeObjectSchema(schema1, schema2)
      try compositeSchema.test(
        (("Alice"), ("25")),
        isCodedAs: "{\"name\":\"Alice\",\"age\":\"25\"}"
      )
    }

    @Test
    func compositeObjectEncodingPropertyOrder() throws {
      let schema1 = SchemaCoding.Support.objectSchema(
        propertyName: CodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let schema2 = SchemaCoding.Support.objectSchema(
        propertyName: AgeCodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: AgeCodingKeys.age,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let compositeSchema = SchemaCoding.Support.CompositeObjectSchema(schema1, schema2)
      try compositeSchema.test(
        (("Bob"), ("30")),
        encodesAs: "{\"name\":\"Bob\",\"age\":\"30\"}"
      )
    }

    @Test
    func compositeObjectDecodingDifferentPropertyOrder() throws {
      let schema1 = SchemaCoding.Support.objectSchema(
        propertyName: CodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let schema2 = SchemaCoding.Support.objectSchema(
        propertyName: AgeCodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: AgeCodingKeys.age,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let compositeSchema = SchemaCoding.Support.CompositeObjectSchema(schema1, schema2)
      try compositeSchema.test(
        "{\"age\":\"42\",\"name\":\"Charlie\"}",
        decodesAs: (("Charlie"), ("42"))
      )
    }

    @Test
    func compositeObjectMetaMetaMetaSchemaEncoding() throws {
      let schema1 = SchemaCoding.Support.objectSchema(
        propertyName: CodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let schema2 = SchemaCoding.Support.objectSchema(
        propertyName: AgeCodingKeys.self
      ) {
        SchemaCoding.Support.objectProperty(
          name: AgeCodingKeys.age,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
      }
      let compositeSchema = SchemaCoding.Support.CompositeObjectSchema(schema1, schema2)
      let context = SchemaCoding.Support.SchemaContext()
      let metaSchema = compositeSchema.metaSchema(in: context)
      let metaMetaSchema = metaSchema.metaSchema(in: context)
      let metaMetaMetaSchema = metaMetaSchema.metaSchema(in: context)

      try metaSchema.test(
        compositeSchema,
        encodesAs: """
          {
            "properties": {
              "name": {
                "type": "string"
              },
              "age": {
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
                },
                "age": {
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
                  },
                  "age": {
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

}

private enum CodingKeys: String, CodingKey {
  case name
}

private enum AgeCodingKeys: String, CodingKey {
  case age
}

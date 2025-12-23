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
    let metaSchema = schema.metaSchema
    let metaMetaSchema = metaSchema.metaSchema
    let metaMetaMetaSchema = metaMetaSchema.metaSchema

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

  // MARK: - Optional Properties

  @Suite("Optional Properties")
  struct OptionalPropertyTests {

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
      let metaSchema = schema.metaSchema

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

  // MARK: - Nested Objects

  @Suite("Nested Objects")
  struct NestedObjectTests {

    @Test
    func nestedObjectSchema() throws {
      let addressSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "street",
          schema: String.schema
        )
        SchemaCoding.Support.RequiredObjectProperty(
          name: "city",
          schema: String.schema
        )
      }

      let personSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "name",
          schema: String.schema
        )
        SchemaCoding.Support.RequiredObjectProperty(
          name: "address",
          schema: addressSchema
        )
      }

      try personSchema.test(
        ("Alice", ("123 Main St", "Springfield")),
        isCodedAs:
          "{\"name\":\"Alice\",\"address\":{\"street\":\"123 Main St\",\"city\":\"Springfield\"}}"
      )
    }

    @Test
    func nestedObjectSchemaCoding() throws {
      let addressSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "street",
          schema: String.schema
        )
        SchemaCoding.Support.RequiredObjectProperty(
          name: "city",
          schema: String.schema
        )
      }

      let personSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "name",
          schema: String.schema
        )
        SchemaCoding.Support.RequiredObjectProperty(
          name: "address",
          schema: addressSchema
        )
      }

      try personSchema.test(
        ("Bob", ("456 Oak Ave", "Boston")),
        isCodedAs: "{\"name\":\"Bob\",\"address\":{\"street\":\"456 Oak Ave\",\"city\":\"Boston\"}}"
      )
    }

    @Test
    func nestedObjectWithOptionalProperty() throws {
      let addressSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "city",
          schema: String.schema
        )
      }

      let personSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "name",
          schema: String.schema
        )
        SchemaCoding.Support.OptionalObjectProperty(
          name: "address",
          schema: addressSchema
        )
      }

      try personSchema.test(
        ("Alice", ("Boston")),
        isCodedAs: "{\"name\":\"Alice\",\"address\":{\"city\":\"Boston\"}}"
      )
      try personSchema.test(
        ("Bob", nil),
        isCodedAs: "{\"name\":\"Bob\"}"
      )
    }

    @Test
    func nestedObjectWithOptionalPropertyDecoding() throws {
      let addressSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "city",
          schema: String.schema
        )
      }

      let personSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "name",
          schema: String.schema
        )
        SchemaCoding.Support.OptionalObjectProperty(
          name: "address",
          schema: addressSchema
        )
      }

      try personSchema.test(
        "{\"name\":\"Alice\",\"address\":{\"city\":\"Boston\"}}",
        decodesAs: ("Alice", ("Boston") as (String)?)
      )
      try personSchema.test(
        "{\"name\":\"Bob\"}",
        decodesAs: ("Bob", nil as (String)?)
      )
    }

    @Test
    func nestedObjectMetaSchema() throws {
      let addressSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "city",
          schema: String.schema
        )
      }

      let personSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "name",
          schema: String.schema
        )
        SchemaCoding.Support.RequiredObjectProperty(
          name: "address",
          schema: addressSchema
        )
      }

      let metaSchema = personSchema.metaSchema

      try metaSchema.test(
        personSchema,
        encodesAs: """
          {
            "properties": {
              "name": {
                "type": "string"
              },
              "address": {
                "properties": {
                  "city": {
                    "type": "string"
                  }
                },
                "required": [
                  "city"
                ]
              }
            },
            "required": [
              "name",
              "address"
            ]
          }
          """,
        prettyPrint: true
      )
    }

  }

  // MARK: - Composite Properties

  @Suite("Composite Properties")
  struct CompositePropertiesTests {

    @Test
    func compositeObjectSchemaProperties() throws {
      let nameProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "firstName",
          schema: String.schema
        ),
        SchemaCoding.Support.RequiredObjectProperty(
          name: "lastName",
          schema: String.schema
        )
      )

      let ageProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "age",
          schema: Int.schema
        )
      )

      let composedSchema = SchemaCoding.Support.ConcreteObjectSchema(
        components: nameProperties, ageProperties
      )

      try composedSchema.test(
        (("Alice", "Smith"), (30)),
        isCodedAs: "{\"firstName\":\"Alice\",\"lastName\":\"Smith\",\"age\":30}"
      )
    }

    @Test
    func compositeObjectSchemaPropertiesDecoding() throws {
      let nameProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "firstName",
          schema: String.schema
        ),
        SchemaCoding.Support.RequiredObjectProperty(
          name: "lastName",
          schema: String.schema
        )
      )

      let ageProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "age",
          schema: Int.schema
        )
      )

      let composedSchema = SchemaCoding.Support.ConcreteObjectSchema(
        components: nameProperties, ageProperties
      )

      try composedSchema.test(
        (("Bob", "Jones"), (25)),
        isCodedAs: "{\"firstName\":\"Bob\",\"lastName\":\"Jones\",\"age\":25}"
      )
    }

    @Test
    func compositeWithOptionalProperties() throws {
      let requiredProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "id",
          schema: Int.schema
        )
      )

      let optionalProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.OptionalObjectProperty(
          name: "nickname",
          schema: String.schema
        )
      )

      let composedSchema = SchemaCoding.Support.ConcreteObjectSchema(
        components: requiredProperties, optionalProperties
      )

      try composedSchema.test(
        ((42), ("Bob" as String?)),
        isCodedAs: "{\"id\":42,\"nickname\":\"Bob\"}"
      )
      try composedSchema.test(
        ((42), (nil as String?)),
        isCodedAs: "{\"id\":42}"
      )
    }

    @Test
    func threeComponentComposition() throws {
      let nameProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "name",
          schema: String.schema
        )
      )

      let ageProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "age",
          schema: Int.schema
        )
      )

      let emailProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "email",
          schema: String.schema
        )
      )

      let composedSchema = SchemaCoding.Support.ConcreteObjectSchema(
        components: nameProperties, ageProperties, emailProperties
      )

      try composedSchema.test(
        (("Alice"), (30), ("alice@example.com")),
        isCodedAs: "{\"name\":\"Alice\",\"age\":30,\"email\":\"alice@example.com\"}"
      )
    }

    @Test
    func compositeObjectSchemaMetaSchema() throws {
      let nameProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "firstName",
          schema: String.schema
        ),
        SchemaCoding.Support.RequiredObjectProperty(
          name: "lastName",
          schema: String.schema
        )
      )

      let ageProperties = SchemaCoding.Support.TupleObjectSchemaProperties(
        SchemaCoding.Support.RequiredObjectProperty(
          name: "age",
          schema: Int.schema
        )
      )

      let composedSchema = SchemaCoding.Support.ConcreteObjectSchema(
        components: nameProperties, ageProperties
      )

      let metaSchema = composedSchema.metaSchema

      try metaSchema.test(
        composedSchema,
        encodesAs: """
          {
            "properties": {
              "firstName": {
                "type": "string"
              },
              "lastName": {
                "type": "string"
              },
              "age": {
                "type": "integer"
              }
            },
            "required": [
              "firstName",
              "lastName",
              "age"
            ]
          }
          """,
        prettyPrint: true
      )
    }

  }

  // MARK: - Arrays of Objects

  @Suite("Arrays of Objects")
  struct ArrayOfObjectsTests {

    @Test
    func objectWithEmptyArrayOfObjects() throws {
      let itemSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "name",
          schema: String.schema
        )
      }

      let containerSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "items",
          schema: SchemaCoding.Support.ArraySchema(elementSchema: itemSchema)
        )
      }

      try containerSchema.test(
        ([] as [(String)]),
        isCodedAs: "{\"items\":[]}"
      )
    }

    @Test
    func nestedArraysOfObjects() throws {
      let cellSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "value",
          schema: Int.schema
        )
      }

      let rowSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "cells",
          schema: SchemaCoding.Support.ArraySchema(elementSchema: cellSchema)
        )
      }

      let gridSchema = SchemaCoding.Support.ConcreteObjectSchema {
        SchemaCoding.Support.RequiredObjectProperty(
          name: "rows",
          schema: SchemaCoding.Support.ArraySchema(elementSchema: rowSchema)
        )
      }

      try gridSchema.test(
        ([([((1)), ((2))]), ([((3)), ((4))])]),
        isCodedAs:
          "{\"rows\":[{\"cells\":[{\"value\":1},{\"value\":2}]},{\"cells\":[{\"value\":3},{\"value\":4}]}]}"
      )
    }

  }

}

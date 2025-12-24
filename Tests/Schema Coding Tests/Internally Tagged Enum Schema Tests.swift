import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Internally Tagged Enum Schema")
struct InternallyTaggedEnumSchemaTests {

  @Test
  func singleCaseWithLabeledAssociatedValue() throws {
    enum Shape: Equatable {
      case circle(radius: Int)
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: Shape.self,
      style: .internallyTagged(discriminatorPropertyName: "type"),
      cases: {
        SchemaCoding.Support.enumSchemaCase(
          name: "circle",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "radius",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int>) in
            Shape.circle(radius: decoder.associatedValues)
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .circle(let radius):
          let encoding = encoder.encodings.0
          encoder.encode(radius, using: encoding)
        }
      }
    )

    try schema.test(Shape.circle(radius: 5), isCodedAs: #"{"type":"circle","radius":5}"#)
  }

  @Test
  func multipleCasesWithVariousAssociatedValues() throws {
    enum Shape: Equatable {
      case circle(radius: Int)
      case rectangle(width: Int, height: Int)
      case point
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: Shape.self,
      style: .internallyTagged(discriminatorPropertyName: "kind"),
      cases: {
        SchemaCoding.Support.enumSchemaCase(
          name: "circle",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "radius",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int>) in
            Shape.circle(radius: decoder.associatedValues)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "rectangle",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "width",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "height",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int, Int>) in
            Shape.rectangle(width: decoder.associatedValues.0, height: decoder.associatedValues.1)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "point",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            Shape.point
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .circle(let radius):
          let encoding = encoder.encodings.0
          encoder.encode(radius, using: encoding)
        case .rectangle(let width, let height):
          let encoding = encoder.encodings.1
          encoder.encode((width, height), using: encoding)
        case .point:
          let encoding = encoder.encodings.2
          encoder.encode((), using: encoding)
        }
      }
    )

    try schema.test(Shape.circle(radius: 10), isCodedAs: #"{"kind":"circle","radius":10}"#)
    try schema.test(
      Shape.rectangle(width: 5, height: 3), isCodedAs: #"{"kind":"rectangle","width":5,"height":3}"#
    )
    try schema.test(Shape.point, isCodedAs: #"{"kind":"point"}"#)
  }

  @Test
  func metaSchema() throws {
    enum Shape: Equatable {
      case circle(radius: Int)
      case rectangle(width: Int, height: Int)
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: Shape.self,
      description: "A geometric shape",
      style: .internallyTagged(discriminatorPropertyName: "type"),
      cases: {
        SchemaCoding.Support.enumSchemaCase(
          name: "circle",
          description: "A circle with a radius",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "radius",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int>) in
            Shape.circle(radius: decoder.associatedValues)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "rectangle",
          description: "A rectangle with width and height",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "width",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "height",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<Int, Int>) in
            Shape.rectangle(width: decoder.associatedValues.0, height: decoder.associatedValues.1)
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .circle(let radius):
          let encoding = encoder.encodings.0
          encoder.encode(radius, using: encoding)
        case .rectangle(let width, let height):
          let encoding = encoder.encodings.1
          encoder.encode((width, height), using: encoding)
        }
      }
    )

    try schema.test(
      encodesAs: """
        {
          "description": "A geometric shape",
          "oneOf": [
            {
              "description": "A circle with a radius",
              "properties": {
                "type": {
                  "const": "circle"
                },
                "radius": {
                  "type": "integer"
                }
              },
              "required": [
                "type",
                "radius"
              ]
            },
            {
              "description": "A rectangle with width and height",
              "properties": {
                "type": {
                  "const": "rectangle"
                },
                "width": {
                  "type": "integer"
                },
                "height": {
                  "type": "integer"
                }
              },
              "required": [
                "type",
                "width",
                "height"
              ]
            }
          ]
        }
        """,
      prettyPrint: true
    )
  }

  @Test
  func metaMetaMetaSchema() throws {
    // A complex enum with various associated value types
    enum APIRequest: Equatable {
      case fetch(endpoint: String, timeout: Int, retryCount: Int)
      case upload(data: String, compressed: Bool)
      case batch(operations: String)
      case cancel
    }

    let schema = SchemaCoding.Support.enumSchema(
      representing: APIRequest.self,
      description: "An API request type",
      style: .internallyTagged(discriminatorPropertyName: "action"),
      cases: {
        SchemaCoding.Support.enumSchemaCase(
          name: "fetch",
          description: "Fetch data from an endpoint",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "endpoint",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "timeout",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "retryCount",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<String, Int, Int>) in
            APIRequest.fetch(
              endpoint: decoder.associatedValues.0,
              timeout: decoder.associatedValues.1,
              retryCount: decoder.associatedValues.2
            )
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "upload",
          description: "Upload data",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "data",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "compressed",
              schema: SchemaCoding.Support.schema(representing: Bool.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<String, Bool>) in
            APIRequest.upload(
              data: decoder.associatedValues.0, compressed: decoder.associatedValues.1)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "batch",
          description: "Batch operations",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "operations",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumDecoder<String>) in
            APIRequest.batch(operations: decoder.associatedValues)
          }
        )
        SchemaCoding.Support.enumSchemaCase(
          name: "cancel",
          description: "Cancel all pending requests",
          associatedValues: {},
          finishDecoding: { (_: SchemaCoding.EnumDecoder<>) in
            APIRequest.cancel
          }
        )
      },
      encodeValue: { value, encoder in
        switch value {
        case .fetch(let endpoint, let timeout, let retryCount):
          let encoding = encoder.encodings.0
          encoder.encode((endpoint, timeout, retryCount), using: encoding)
        case .upload(let data, let compressed):
          let encoding = encoder.encodings.1
          encoder.encode((data, compressed), using: encoding)
        case .batch(let operations):
          let encoding = encoder.encodings.2
          encoder.encode(operations, using: encoding)
        case .cancel:
          let encoding = encoder.encodings.3
          encoder.encode((), using: encoding)
        }
      }
    )

    // Try meta-meta first to see if that works
    let metaMetaSchema = schema.metaSchema.metaSchema

    // Just verify it doesn't crash and produces valid JSON
    var encoder = SchemaCoding.Support.Encoder()
    encoder.stream.options = [.prettyPrint]
    metaMetaSchema.encode(schema.metaSchema, to: &encoder)
    let json = encoder.stream.stringRepresentation

    // Verify we got valid JSON
    #expect(
      json == """
        {
          "properties": {
            "description": {
              "type": "string"
            },
            "oneOf": {
              "prefixItems": [
                {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "properties": {
                      "properties": {
                        "action": {
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
                        },
                        "endpoint": {
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
                        "timeout": {
                          "properties": {
                            "description": {
                              "type": "string"
                            },
                            "type": {
                              "const": "integer"
                            }
                          },
                          "required": [
                            "type"
                          ]
                        },
                        "retryCount": {
                          "properties": {
                            "description": {
                              "type": "string"
                            },
                            "type": {
                              "const": "integer"
                            }
                          },
                          "required": [
                            "type"
                          ]
                        }
                      },
                      "required": [
                        "action",
                        "endpoint",
                        "timeout",
                        "retryCount"
                      ]
                    },
                    "required": {
                      "const": [
                        "action",
                        "endpoint",
                        "timeout",
                        "retryCount"
                      ]
                    }
                  },
                  "required": [
                    "properties",
                    "required"
                  ]
                },
                {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "properties": {
                      "properties": {
                        "action": {
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
                        },
                        "data": {
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
                        "compressed": {
                          "properties": {
                            "description": {
                              "type": "string"
                            },
                            "type": {
                              "const": "boolean"
                            }
                          },
                          "required": [
                            "type"
                          ]
                        }
                      },
                      "required": [
                        "action",
                        "data",
                        "compressed"
                      ]
                    },
                    "required": {
                      "const": [
                        "action",
                        "data",
                        "compressed"
                      ]
                    }
                  },
                  "required": [
                    "properties",
                    "required"
                  ]
                },
                {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "properties": {
                      "properties": {
                        "action": {
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
                        },
                        "operations": {
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
                        "action",
                        "operations"
                      ]
                    },
                    "required": {
                      "const": [
                        "action",
                        "operations"
                      ]
                    }
                  },
                  "required": [
                    "properties",
                    "required"
                  ]
                },
                {
                  "properties": {
                    "description": {
                      "type": "string"
                    },
                    "properties": {
                      "properties": {
                        "action": {
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
                        "action"
                      ]
                    },
                    "required": {
                      "const": [
                        "action"
                      ]
                    }
                  },
                  "required": [
                    "properties",
                    "required"
                  ]
                }
              ]
            }
          },
          "required": [
            "oneOf"
          ]
        }
        """)
  }

}

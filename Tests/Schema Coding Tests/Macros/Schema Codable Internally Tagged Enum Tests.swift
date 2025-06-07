import Testing
/*
@testable import SchemaCoding

@Suite("Schema Codable Internally Tagged Enum Macro Tests")
private struct SchemaCodableInternallyTaggedEnumMacroTests {

  // MARK: - Shape Tests

  /// A shape with associated values
  @SchemaCodable(discriminatorPropertyName: "type")
  enum Shape: Equatable {
    /// A circle with a radius
    case circle(radius: Double)
    /// A rectangle with width and height
    case rectangle(width: Double, height: Double)
    /// A square with a side length
    case square(side: Double)
  }

  @Test
  private func testShapeSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: Shape.self)
    #expect(
      schema.schemaJSON == """
        {
          "description" : "A shape with associated values",
          "oneOf" : [
            {
              "description" : "A circle with a radius",
              "properties" : {
                "radius" : {
                  "type" : "number"
                },
                "type" : {
                  "const" : "circle"
                }
              },
              "required" : [
                "type",
                "radius"
              ],
              "type" : "object"
            },
            {
              "description" : "A rectangle with width and height",
              "properties" : {
                "height" : {
                  "type" : "number"
                },
                "type" : {
                  "const" : "rectangle"
                },
                "width" : {
                  "type" : "number"
                }
              },
              "required" : [
                "type",
                "width",
                "height"
              ],
              "type" : "object"
            },
            {
              "description" : "A square with a side length",
              "properties" : {
                "side" : {
                  "type" : "number"
                },
                "type" : {
                  "const" : "square"
                }
              },
              "required" : [
                "type",
                "side"
              ],
              "type" : "object"
            }
          ]
        }
        """)
  }

  @Test
  private func testShapeValueEncoding() throws {
    let schema = SchemaSupport.schema(representing: Shape.self)

    #expect(
      schema.encodedJSON(for: .circle(radius: 5.0)) == """
        {
          "radius" : 5,
          "type" : "circle"
        }
        """)

    #expect(
      schema.encodedJSON(for: .rectangle(width: 10.0, height: 20.0)) == """
        {
          "height" : 20,
          "type" : "rectangle",
          "width" : 10
        }
        """)

    #expect(
      schema.encodedJSON(for: .square(side: 15.0)) == """
        {
          "side" : 15,
          "type" : "square"
        }
        """)
  }

  @Test
  private func testShapeValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: Shape.self)

    #expect(
      schema.value(
        fromJSON: """
          {
            "type": "circle",
            "radius": 5.0
          }
          """) == .circle(radius: 5.0))

    #expect(
      schema.value(
        fromJSON: """
          {
            "width": 10.0,
            "type": "rectangle",
            "height": 20.0
          }
          """) == .rectangle(width: 10.0, height: 20.0))

    #expect(
      schema.value(
        fromJSON: """
          {
            "side": 15.0,
            "type": "square"
          }
          """) == .square(side: 15.0))
  }

  // MARK: - Animal Tests

  /// An animal with different properties
  @SchemaCodable(discriminatorPropertyName: "type")
  enum Animal: Equatable {
    /// A dog with a name and favorite toy
    case dog(name: String, favoriteToy: String)
    /// A cat with a name and number of lives
    case cat(name: String, lives: Int)
    /// A bird that can fly
    case bird(canFly: Bool)
  }

  @Test
  private func testAnimalSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: Animal.self)
    #expect(
      schema.schemaJSON == """
        {
          "description" : "An animal with different properties",
          "oneOf" : [
            {
              "description" : "A dog with a name and favorite toy",
              "properties" : {
                "favoriteToy" : {
                  "type" : "string"
                },
                "name" : {
                  "type" : "string"
                },
                "type" : {
                  "const" : "dog"
                }
              },
              "required" : [
                "type",
                "name",
                "favoriteToy"
              ],
              "type" : "object"
            },
            {
              "description" : "A cat with a name and number of lives",
              "properties" : {
                "lives" : {
                  "type" : "integer"
                },
                "name" : {
                  "type" : "string"
                },
                "type" : {
                  "const" : "cat"
                }
              },
              "required" : [
                "type",
                "name",
                "lives"
              ],
              "type" : "object"
            },
            {
              "description" : "A bird that can fly",
              "properties" : {
                "canFly" : {
                  "type" : "boolean"
                },
                "type" : {
                  "const" : "bird"
                }
              },
              "required" : [
                "type",
                "canFly"
              ],
              "type" : "object"
            }
          ]
        }
        """)
  }

  @Test
  private func testAnimalValueEncoding() throws {
    let schema = SchemaSupport.schema(representing: Animal.self)

    #expect(
      schema.encodedJSON(for: .dog(name: "Buddy", favoriteToy: "Tennis Ball")) == """
        {
          "favoriteToy" : "Tennis Ball",
          "name" : "Buddy",
          "type" : "dog"
        }
        """)

    #expect(
      schema.encodedJSON(for: .cat(name: "Whiskers", lives: 9)) == """
        {
          "lives" : 9,
          "name" : "Whiskers",
          "type" : "cat"
        }
        """)

    #expect(
      schema.encodedJSON(for: .bird(canFly: true)) == """
        {
          "canFly" : true,
          "type" : "bird"
        }
        """)
  }

  @Test
  private func testAnimalValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: Animal.self)

    #expect(
      schema.value(
        fromJSON: """
          {
            "type": "dog",
            "name": "Buddy",
            "favoriteToy": "Tennis Ball"
          }
          """) == .dog(name: "Buddy", favoriteToy: "Tennis Ball"))

    #expect(
      schema.value(
        fromJSON: """
          {
            "lives": 9,
            "type": "cat",
            "name": "Whiskers"
          }
          """) == .cat(name: "Whiskers", lives: 9))

    #expect(
      schema.value(
        fromJSON: """
          {
            "canFly": true,
            "type": "bird"
          }
          """) == .bird(canFly: true))
  }

  // MARK: - Payment Method Tests

  /// A payment method for transactions
  @SchemaCodable(discriminatorPropertyName: "type")
  enum PaymentMethod: Equatable {
    /// Credit card payment
    case creditCard(number: String, cvv: String, expiryMonth: Int, expiryYear: Int)
    /// Bank transfer payment
    case bankTransfer(accountNumber: String, routingNumber: String)
    /// Digital wallet payment
    case digitalWallet(walletId: String)
  }

  @Test
  private func testPaymentMethodSchemaEncoding() throws {
    let schema = SchemaSupport.schema(representing: PaymentMethod.self)
    #expect(
      schema.schemaJSON == """
        {
          "description" : "A payment method for transactions",
          "oneOf" : [
            {
              "description" : "Credit card payment",
              "properties" : {
                "cvv" : {
                  "type" : "string"
                },
                "expiryMonth" : {
                  "type" : "integer"
                },
                "expiryYear" : {
                  "type" : "integer"
                },
                "number" : {
                  "type" : "string"
                },
                "type" : {
                  "const" : "creditCard"
                }
              },
              "required" : [
                "type",
                "number",
                "cvv",
                "expiryMonth",
                "expiryYear"
              ],
              "type" : "object"
            },
            {
              "description" : "Bank transfer payment",
              "properties" : {
                "accountNumber" : {
                  "type" : "string"
                },
                "routingNumber" : {
                  "type" : "string"
                },
                "type" : {
                  "const" : "bankTransfer"
                }
              },
              "required" : [
                "type",
                "accountNumber",
                "routingNumber"
              ],
              "type" : "object"
            },
            {
              "description" : "Digital wallet payment",
              "properties" : {
                "type" : {
                  "const" : "digitalWallet"
                },
                "walletId" : {
                  "type" : "string"
                }
              },
              "required" : [
                "type",
                "walletId"
              ],
              "type" : "object"
            }
          ]
        }
        """)
  }

  @Test
  private func testPaymentMethodValueEncoding() throws {
    let schema = SchemaSupport.schema(representing: PaymentMethod.self)

    #expect(
      schema.encodedJSON(
        for: .creditCard(number: "4111111111111111", cvv: "123", expiryMonth: 12, expiryYear: 2025))
          == """
          {
            "cvv" : "123",
            "expiryMonth" : 12,
            "expiryYear" : 2025,
            "number" : "4111111111111111",
            "type" : "creditCard"
          }
          """)

    #expect(
      schema.encodedJSON(for: .bankTransfer(accountNumber: "123456789", routingNumber: "987654321"))
        == """
        {
          "accountNumber" : "123456789",
          "routingNumber" : "987654321",
          "type" : "bankTransfer"
        }
        """)

    #expect(
      schema.encodedJSON(for: .digitalWallet(walletId: "wallet_abc123")) == """
        {
          "type" : "digitalWallet",
          "walletId" : "wallet_abc123"
        }
        """)
  }

  @Test
  private func testPaymentMethodValueDecoding() throws {
    let schema = SchemaSupport.schema(representing: PaymentMethod.self)

    #expect(
      schema.value(
        fromJSON: """
          {
            "type": "creditCard",
            "number": "4111111111111111",
            "cvv": "123",
            "expiryMonth": 12,
            "expiryYear": 2025
          }
          """)
        == .creditCard(number: "4111111111111111", cvv: "123", expiryMonth: 12, expiryYear: 2025))

    #expect(
      schema.value(
        fromJSON: """
          {
            "routingNumber": "987654321",
            "type": "bankTransfer",
            "accountNumber": "123456789"
          }
          """) == .bankTransfer(accountNumber: "123456789", routingNumber: "987654321"))

    #expect(
      schema.value(
        fromJSON: """
          {
            "walletId": "wallet_abc123",
            "type": "digitalWallet"
          }
          """) == .digitalWallet(walletId: "wallet_abc123"))
  }
}
*/

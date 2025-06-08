import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Schema Codable Internally Tagged Enum Macro")
struct SchemaCodableInternallyTaggedEnumMacroTests {

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
    let schema = SchemaCoding.SchemaResolver.schema(representing: Shape.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "A shape with associated values",
          "oneOf": [
            {
              "description": "A circle with a radius",
              "properties": {
                "type": {
                  "const": "circle"
                },
                "radius": {
                  "type": "number"
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
                  "type": "number"
                },
                "height": {
                  "type": "number"
                }
              },
              "required": [
                "type",
                "width",
                "height"
              ]
            },
            {
              "description": "A square with a side length",
              "properties": {
                "type": {
                  "const": "square"
                },
                "side": {
                  "type": "number"
                }
              },
              "required": [
                "type",
                "side"
              ]
            }
          ]
        }
        """)
  }

  @Test
  private func testShapeValueEncoding() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: Shape.self)

    #expect(
      schema.encodedJSON(for: .circle(radius: 5.0)) == """
        {
          "type": "circle",
          "radius": 5.0
        }
        """)

    #expect(
      schema.encodedJSON(for: .rectangle(width: 10.0, height: 20.0)) == """
        {
          "type": "rectangle",
          "width": 10.0,
          "height": 20.0
        }
        """)

    #expect(
      schema.encodedJSON(for: .square(side: 15.0)) == """
        {
          "type": "square",
          "side": 15.0
        }
        """)
  }

  @Test
  private func testShapeValueDecoding() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: Shape.self)

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
    let schema = SchemaCoding.SchemaResolver.schema(representing: Animal.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "An animal with different properties",
          "oneOf": [
            {
              "description": "A dog with a name and favorite toy",
              "properties": {
                "type": {
                  "const": "dog"
                },
                "name": {
                  "type": "string"
                },
                "favoriteToy": {
                  "type": "string"
                }
              },
              "required": [
                "type",
                "name",
                "favoriteToy"
              ]
            },
            {
              "description": "A cat with a name and number of lives",
              "properties": {
                "type": {
                  "const": "cat"
                },
                "name": {
                  "type": "string"
                },
                "lives": {
                  "type": "integer"
                }
              },
              "required": [
                "type",
                "name",
                "lives"
              ]
            },
            {
              "description": "A bird that can fly",
              "properties": {
                "type": {
                  "const": "bird"
                },
                "canFly": {
                  "type": "boolean"
                }
              },
              "required": [
                "type",
                "canFly"
              ]
            }
          ]
        }
        """)
  }

  @Test
  private func testAnimalValueEncoding() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: Animal.self)

    #expect(
      schema.encodedJSON(for: .dog(name: "Buddy", favoriteToy: "Tennis Ball")) == """
        {
          "type": "dog",
          "name": "Buddy",
          "favoriteToy": "Tennis Ball"
        }
        """)

    #expect(
      schema.encodedJSON(for: .cat(name: "Whiskers", lives: 9)) == """
        {
          "type": "cat",
          "name": "Whiskers",
          "lives": 9
        }
        """)

    #expect(
      schema.encodedJSON(for: .bird(canFly: true)) == """
        {
          "type": "bird",
          "canFly": true
        }
        """)
  }

  @Test
  private func testAnimalValueDecoding() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: Animal.self)

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
    let schema = SchemaCoding.SchemaResolver.schema(representing: PaymentMethod.self)
    #expect(
      schema.schemaJSON == """
        {
          "description": "A payment method for transactions",
          "oneOf": [
            {
              "description": "Credit card payment",
              "properties": {
                "type": {
                  "const": "creditCard"
                },
                "number": {
                  "type": "string"
                },
                "cvv": {
                  "type": "string"
                },
                "expiryMonth": {
                  "type": "integer"
                },
                "expiryYear": {
                  "type": "integer"
                }
              },
              "required": [
                "type",
                "number",
                "cvv",
                "expiryMonth",
                "expiryYear"
              ]
            },
            {
              "description": "Bank transfer payment",
              "properties": {
                "type": {
                  "const": "bankTransfer"
                },
                "accountNumber": {
                  "type": "string"
                },
                "routingNumber": {
                  "type": "string"
                }
              },
              "required": [
                "type",
                "accountNumber",
                "routingNumber"
              ]
            },
            {
              "description": "Digital wallet payment",
              "properties": {
                "type": {
                  "const": "digitalWallet"
                },
                "walletId": {
                  "type": "string"
                }
              },
              "required": [
                "type",
                "walletId"
              ]
            }
          ]
        }
        """)
  }

  @Test
  private func testPaymentMethodValueEncoding() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: PaymentMethod.self)

    #expect(
      schema.encodedJSON(
        for: .creditCard(number: "4111111111111111", cvv: "123", expiryMonth: 12, expiryYear: 2025))
          == """
          {
            "type": "creditCard",
            "number": "4111111111111111",
            "cvv": "123",
            "expiryMonth": 12,
            "expiryYear": 2025
          }
          """)

    #expect(
      schema.encodedJSON(for: .bankTransfer(accountNumber: "123456789", routingNumber: "987654321"))
        == """
        {
          "type": "bankTransfer",
          "accountNumber": "123456789",
          "routingNumber": "987654321"
        }
        """)

    #expect(
      schema.encodedJSON(for: .digitalWallet(walletId: "wallet_abc123")) == """
        {
          "type": "digitalWallet",
          "walletId": "wallet_abc123"
        }
        """)
  }

  @Test
  private func testPaymentMethodValueDecoding() throws {
    let schema = SchemaCoding.SchemaResolver.schema(representing: PaymentMethod.self)

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

import SchemaCodingTestSupport
import Testing

@testable import JSONSupport
@testable import SchemaCoding

@Suite("Object")
struct ObjectSchemaTests {

  @Test
  private func testEmptyObject() throws {
    let schema = SchemaCoding.Support.objectSchema()
    try schema.test((), isCodedAs: "{}")
  }

  @Test
  private func testSingleProperty() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties: SchemaCoding.Support.objectProperty(
        name: CodingKeys.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
    )
    try schema.test(("Alice"), isCodedAs: "{\"name\":\"Alice\"}")
  }

  @Test
  private func testMultipleProperties() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: SchemaCoding.Support.schema(representing: String.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.age,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.isActive,
        schema: SchemaCoding.Support.schema(representing: Bool.self)
      )
    )
    try schema.test(
      ("Bob", 30, true), isCodedAs: "{\"name\":\"Bob\",\"age\":30,\"isActive\":true}")

    /// Decode properties out-of-order
    try schema.test(
      "{\"age\":30,\"name\":\"Bob\",\"isActive\":true}", decodesAs: ("Bob", 30, true))
  }

  @Test
  private func testOptionalProperties() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: String.schema
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.nickname,
        schema: String?.schema
      )
    )

    try schema.test(("John", nil as String?), isCodedAs: "{\"name\":\"John\"}")
    try schema.test(("Jane", "J" as String?), isCodedAs: "{\"name\":\"Jane\",\"nickname\":\"J\"}")
  }

  @Test
  private func testMixedTypes() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: MixedKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: MixedKeys.string,
          schema: SchemaCoding.Support.schema(representing: String.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: MixedKeys.int,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      ),
      SchemaCoding.Support.objectProperty(
        name: MixedKeys.double,
        schema: SchemaCoding.Support.schema(representing: Double.self)
      ),
      SchemaCoding.Support.objectProperty(
        name: MixedKeys.bool,
        schema: SchemaCoding.Support.schema(representing: Bool.self)
      )
    )

    try schema.test(
      ("test", 42, 3.14, true),
      isCodedAs: "{\"string\":\"test\",\"int\":42,\"double\":3.14,\"bool\":true}"
    )
  }

  @Test
  private func testArrayProperty() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: SchemaCoding.Support.schema(representing: String.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.tags,
        schema: SchemaCoding.Support.schema(representing: [String].self)
      )
    )

    try schema.test(
      ("Item", ["red", "large", "sale"]),
      isCodedAs: "{\"name\":\"Item\",\"tags\":[\"red\",\"large\",\"sale\"]}")
    try schema.test(("Product", []), isCodedAs: "{\"name\":\"Product\",\"tags\":[]}")
  }

  @Test
  private func testFloatingPointPrecision() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.floatValue,
          schema: SchemaCoding.Support.schema(representing: Float.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.doubleValue,
        schema: SchemaCoding.Support.schema(representing: Double.self)
      )
    )

    try schema.test(
      (Float(3.14), 2.71828), isCodedAs: "{\"floatValue\":3.14,\"doubleValue\":2.71828}")
    try schema.test((Float(0.0), 0.0), isCodedAs: "{\"floatValue\":0.0,\"doubleValue\":0.0}")
    try schema.test(
      (Float(-1.5), -999.999), isCodedAs: "{\"floatValue\":-1.5,\"doubleValue\":-999.999}")
  }

  @Test
  private func testVerySmallNumbers() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.tiny,
          schema: SchemaCoding.Support.schema(representing: Double.self)
        )
    )

    try schema.test((0.0000001), isCodedAs: "{\"tiny\":1e-07}")
  }

  @Test
  private func testLargeNumbers() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.large,
          schema: SchemaCoding.Support.schema(representing: Int.self)
        )
    )

    try schema.test((999_999_999), isCodedAs: "{\"large\":999999999}")
  }

  @Test
  private func testEmptyStringProperty() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.empty,
          schema: SchemaCoding.Support.schema(representing: String.self)
        )
    )

    try schema.test((""), isCodedAs: "{\"empty\":\"\"}")
  }

  @Test
  private func testNegativeNumbers() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.negative,
          schema: SchemaCoding.Support.schema(representing: Int.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.negativeFloat,
        schema: SchemaCoding.Support.schema(representing: Double.self)
      )
    )

    try schema.test((-42, -3.14), isCodedAs: "{\"negative\":-42,\"negativeFloat\":-3.14}")
  }

  @Test
  private func testZeroValues() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.zeroInt,
          schema: SchemaCoding.Support.schema(representing: Int.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.zeroDouble,
        schema: SchemaCoding.Support.schema(representing: Double.self)
      )
    )

    try schema.test((0, 0.0), isCodedAs: "{\"zeroInt\":0,\"zeroDouble\":0.0}")
  }

  @Test
  private func testBooleanProperties() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.isTrue,
          schema: SchemaCoding.Support.schema(representing: Bool.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.isFalse,
        schema: SchemaCoding.Support.schema(representing: Bool.self)
      )
    )

    try schema.test((true, false), isCodedAs: "{\"isTrue\":true,\"isFalse\":false}")
  }

  @Test
  private func testObjectPropertiesBuilder() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self
    ) {
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.age,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
    }

    try schema.test(("Bob", 25), isCodedAs: "{\"name\":\"Bob\",\"age\":25}")
  }

  @Test
  private func testOptionalWithNullEncoding() throws {
    // Using Optional<T>.schema directly encodes nil as null
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.name,
          schema: SchemaCoding.Support.schema(representing: String.self)
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.nullable,
        schema: Optional<String>.schema
      )
    )

    try schema.test(("Test", nil as String?), isCodedAs: "{\"name\":\"Test\"}")
    try schema.test(
      ("Test", "value" as String?), isCodedAs: "{\"name\":\"Test\",\"nullable\":\"value\"}")
  }

  @Test
  private func testAllOptionalProperties() throws {
    let schema = SchemaCoding.Support.objectSchema(
      propertyName: CodingKeys.self,
      properties:
        SchemaCoding.Support.objectProperty(
          name: CodingKeys.optionalString,
          schema: String?.schema
        ),
      SchemaCoding.Support.objectProperty(
        name: CodingKeys.optionalInt,
        schema: Int?.schema
      )
    )

    try schema.test((nil as String?, nil as Int?), isCodedAs: "{}")
    try schema.test(("test" as String?, nil as Int?), isCodedAs: "{\"optionalString\":\"test\"}")
    try schema.test((nil as String?, 42 as Int?), isCodedAs: "{\"optionalInt\":42}")
    try schema.test(
      ("hello" as String?, 100 as Int?),
      isCodedAs: "{\"optionalString\":\"hello\",\"optionalInt\":100}")
  }

}

// MARK: - Coding Keys

private enum CodingKeys: String, CodingKey {
  case name
  case age
  case isActive
  case nickname
  case nullable
  case description
  case version
  case tags
  case floatValue
  case doubleValue
  case tiny
  case large
  case empty
  case negative
  case negativeFloat
  case zeroInt
  case zeroDouble
  case isTrue
  case isFalse
  case optionalString
  case optionalInt
}

private enum AddressKeys: String, CodingKey {
  case street
  case city
}

private enum PersonKeys: String, CodingKey {
  case name
  case address
}

private enum MixedKeys: String, CodingKey {
  case string
  case int
  case double
  case bool
}

private enum ItemKeys: String, CodingKey {
  case id
  case name
}

private enum OrderKeys: String, CodingKey {
  case orderId
  case items
  case total
}

import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Struct Schema")
struct StructSchemaTests {

  @Test
  func structWithSingleProperty() throws {
    struct SimpleStruct: Equatable {
      let value: String
    }

    let schema = SchemaCoding.Support.structSchema(representing: SimpleStruct.self) {
      SchemaCoding.Support.structProperty(
        name: "value",
        keyPath: \SimpleStruct.value,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
    } initializer: { value in
      SimpleStruct(value: value)
    }

    try schema.test(SimpleStruct(value: "hello"), isCodedAs: "{\"value\":\"hello\"}")
  }

  @Test
  func structWithMultipleProperties() throws {
    struct Person: Equatable {
      let name: String
      let age: Int
    }

    let schema = SchemaCoding.Support.structSchema(representing: Person.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \Person.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "age",
        keyPath: \Person.age,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
    } initializer: { name, age in
      Person(name: name, age: age)
    }

    try schema.test(Person(name: "Alice", age: 30), isCodedAs: "{\"name\":\"Alice\",\"age\":30}")
  }

  @Test
  func structWithBooleanProperty() throws {
    struct Settings: Equatable {
      let enabled: Bool
    }

    let schema = SchemaCoding.Support.structSchema(representing: Settings.self) {
      SchemaCoding.Support.structProperty(
        name: "enabled",
        keyPath: \Settings.enabled,
        schema: SchemaCoding.Support.schema(representing: Bool.self)
      )
    } initializer: { enabled in
      Settings(enabled: enabled)
    }

    try schema.test(Settings(enabled: true), isCodedAs: "{\"enabled\":true}")
    try schema.test(Settings(enabled: false), isCodedAs: "{\"enabled\":false}")
  }

  @Test
  func structWithDoubleProperty() throws {
    struct Measurement: Equatable {
      let value: Double
    }

    let schema = SchemaCoding.Support.structSchema(representing: Measurement.self) {
      SchemaCoding.Support.structProperty(
        name: "value",
        keyPath: \Measurement.value,
        schema: SchemaCoding.Support.schema(representing: Double.self)
      )
    } initializer: { value in
      Measurement(value: value)
    }

    try schema.test(Measurement(value: 3.14), isCodedAs: "{\"value\":3.14}")
  }

  @Test
  func structWithOptionalProperty() throws {
    struct User: Equatable {
      let name: String
      let nickname: String?
    }

    let schema = SchemaCoding.Support.structSchema(representing: User.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \User.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "nickname",
        keyPath: \User.nickname,
        schema: String?.schema
      )
    } initializer: { name, nickname in
      User(name: name, nickname: nickname)
    }

    try schema.test(User(name: "Alice", nickname: "Ali"), isCodedAs: "{\"name\":\"Alice\",\"nickname\":\"Ali\"}")
    try schema.test(User(name: "Bob", nickname: nil), isCodedAs: "{\"name\":\"Bob\"}")
  }

  @Test
  func structWithArrayProperty() throws {
    struct Container: Equatable {
      let items: [String]
    }

    let schema = SchemaCoding.Support.structSchema(representing: Container.self) {
      SchemaCoding.Support.structProperty(
        name: "items",
        keyPath: \Container.items,
        schema: [String].schema
      )
    } initializer: { items in
      Container(items: items)
    }

    try schema.test(Container(items: ["a", "b", "c"]), isCodedAs: "{\"items\":[\"a\",\"b\",\"c\"]}")
    try schema.test(Container(items: []), isCodedAs: "{\"items\":[]}")
  }

  @Test
  func structWithDescription() throws {
    struct Point: Equatable {
      let x: Int
      let y: Int
    }

    let schema = SchemaCoding.Support.structSchema(
      representing: Point.self,
      description: "A point in 2D space"
    ) {
      SchemaCoding.Support.structProperty(
        name: "x",
        keyPath: \Point.x,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
      SchemaCoding.Support.structProperty(
        name: "y",
        keyPath: \Point.y,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
    } initializer: { x, y in
      Point(x: x, y: y)
    }

    try schema.test(Point(x: 10, y: 20), isCodedAs: "{\"x\":10,\"y\":20}")
  }

}

@Suite("Struct Schema Decoding")
struct StructSchemaDecodingTests {

  @Test
  func decodeStructWithSingleProperty() throws {
    struct SimpleStruct: Equatable {
      let value: String
    }

    let schema = SchemaCoding.Support.structSchema(representing: SimpleStruct.self) {
      SchemaCoding.Support.structProperty(
        name: "value",
        keyPath: \SimpleStruct.value,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
    } initializer: { value in
      SimpleStruct(value: value)
    }

    try schema.test("{\"value\":\"hello\"}", decodesAs: SimpleStruct(value: "hello"))
  }

  @Test
  func decodeStructWithMultipleProperties() throws {
    struct Person: Equatable {
      let name: String
      let age: Int
    }

    let schema = SchemaCoding.Support.structSchema(representing: Person.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \Person.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "age",
        keyPath: \Person.age,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
    } initializer: { name, age in
      Person(name: name, age: age)
    }

    try schema.test("{\"name\":\"Alice\",\"age\":30}", decodesAs: Person(name: "Alice", age: 30))
  }

  @Test
  func decodeStructWithDifferentPropertyOrder() throws {
    struct Person: Equatable {
      let name: String
      let age: Int
    }

    let schema = SchemaCoding.Support.structSchema(representing: Person.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \Person.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "age",
        keyPath: \Person.age,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
    } initializer: { name, age in
      Person(name: name, age: age)
    }

    try schema.test("{\"age\":25,\"name\":\"Bob\"}", decodesAs: Person(name: "Bob", age: 25))
  }

  @Test
  func decodeStructWithOptionalPropertyPresent() throws {
    struct User: Equatable {
      let name: String
      let nickname: String?
    }

    let schema = SchemaCoding.Support.structSchema(representing: User.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \User.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "nickname",
        keyPath: \User.nickname,
        schema: String?.schema
      )
    } initializer: { name, nickname in
      User(name: name, nickname: nickname)
    }

    try schema.test("{\"name\":\"Alice\",\"nickname\":\"Ali\"}", decodesAs: User(name: "Alice", nickname: "Ali"))
  }

  @Test
  func decodeStructWithOptionalPropertyMissing() throws {
    struct User: Equatable {
      let name: String
      let nickname: String?
    }

    let schema = SchemaCoding.Support.structSchema(representing: User.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \User.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "nickname",
        keyPath: \User.nickname,
        schema: String?.schema
      )
    } initializer: { name, nickname in
      User(name: name, nickname: nickname)
    }

    try schema.test("{\"name\":\"Bob\"}", decodesAs: User(name: "Bob", nickname: nil))
  }

  @Test
  func decodeStructWithWhitespace() throws {
    struct SimpleStruct: Equatable {
      let value: String
    }

    let schema = SchemaCoding.Support.structSchema(representing: SimpleStruct.self) {
      SchemaCoding.Support.structProperty(
        name: "value",
        keyPath: \SimpleStruct.value,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
    } initializer: { value in
      SimpleStruct(value: value)
    }

    try schema.test("{ \"value\" : \"hello\" }", decodesAs: SimpleStruct(value: "hello"))
  }

  @Test
  func chunkedDecoding() throws {
    struct SimpleStruct: Equatable {
      let value: String
    }

    let schema = SchemaCoding.Support.structSchema(representing: SimpleStruct.self) {
      SchemaCoding.Support.structProperty(
        name: "value",
        keyPath: \SimpleStruct.value,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
    } initializer: { value in
      SimpleStruct(value: value)
    }

    try schema.test(
      ["{", "\"value\"", ":", "\"hello\"", "}"],
      decodesAs: SimpleStruct(value: "hello")
    )
  }

}

@Suite("Struct Schema Meta")
struct StructSchemaMetaTests {

  @Test
  func structMetaSchema() throws {
    struct Person: Equatable {
      let name: String
      let age: Int
    }

    let schema = SchemaCoding.Support.structSchema(representing: Person.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \Person.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "age",
        keyPath: \Person.age,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
    } initializer: { name, age in
      Person(name: name, age: age)
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
            "age": {
              "type": "integer"
            }
          },
          "required": [
            "name",
            "age"
          ]
        }
        """,
      prettyPrint: true
    )
  }

  @Test
  func structWithOptionalPropertyMetaSchema() throws {
    struct User: Equatable {
      let name: String
      let nickname: String?
    }

    let schema = SchemaCoding.Support.structSchema(representing: User.self) {
      SchemaCoding.Support.structProperty(
        name: "name",
        keyPath: \User.name,
        schema: SchemaCoding.Support.schema(representing: String.self)
      )
      SchemaCoding.Support.structProperty(
        name: "nickname",
        keyPath: \User.nickname,
        schema: String?.schema
      )
    } initializer: { name, nickname in
      User(name: name, nickname: nickname)
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

  @Test
  func structWithDescriptionMetaSchema() throws {
    struct Point: Equatable {
      let x: Int
      let y: Int
    }

    let schema = SchemaCoding.Support.structSchema(
      representing: Point.self,
      description: "A point in 2D space"
    ) {
      SchemaCoding.Support.structProperty(
        name: "x",
        keyPath: \Point.x,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
      SchemaCoding.Support.structProperty(
        name: "y",
        keyPath: \Point.y,
        schema: SchemaCoding.Support.schema(representing: Int.self)
      )
    } initializer: { x, y in
      Point(x: x, y: y)
    }

    let metaSchema = schema.metaSchema

    try metaSchema.test(
      schema,
      encodesAs: """
        {
          "description": "A point in 2D space",
          "properties": {
            "x": {
              "type": "integer"
            },
            "y": {
              "type": "integer"
            }
          },
          "required": [
            "x",
            "y"
          ]
        }
        """,
      prettyPrint: true
    )
  }

}

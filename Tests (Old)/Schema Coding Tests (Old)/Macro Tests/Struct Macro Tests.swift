import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Struct Macro")
struct StructMacroTests {

  @SchemaCodable
  fileprivate struct SimpleStruct: Equatable {
    let name: String
    let age: Int
  }

  @SchemaCodable(
    style: .wrapper
  )
  fileprivate struct WrapperStruct: Equatable {
    let wrappedValue: String
  }

  @SchemaCodable
  fileprivate struct StructWithOptional: Equatable {
    let required: String
    let optional: Int?
  }

  @SchemaCodable
  fileprivate struct SinglePropertyStruct: Equatable {
    let value: Bool
  }

  @SchemaCodable(description: "A person with a name")
  fileprivate struct DescribedStruct: Equatable {
    let name: String
  }

  @SchemaCodable
  fileprivate struct NestedStruct: Equatable {
    let inner: StructMacroTests.SimpleStruct
  }

  @SchemaCodable
  fileprivate struct StructWithArray: Equatable {
    let items: [String]
  }

  @SchemaCodable
  fileprivate struct MultipleOptionals: Equatable {
    let first: String?
    let second: Int?
    let third: Bool?
  }

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testSimpleStruct() throws {
      try test(
        SimpleStruct(name: "Alice", age: 30),
        isCodedAs: """
          {
            "name": "Alice",
            "age": 30
          }
          """
      )
    }

    @Test
    func testStructWithOptionalPresent() throws {
      try test(
        StructWithOptional(required: "test", optional: 42),
        isCodedAs: """
          {
            "required": "test",
            "optional": 42
          }
          """
      )
    }

    @Test
    func testStructWithOptionalNil() throws {
      try test(
        StructWithOptional(required: "test", optional: nil),
        isCodedAs: """
          {
            "required": "test"
          }
          """
      )
    }

    @Test
    func testSinglePropertyStruct() throws {
      try test(
        SinglePropertyStruct(value: true),
        isCodedAs: """
          {
            "value": true
          }
          """
      )
    }

    @Test
    func testWrapperStruct() throws {
      try test(
        WrapperStruct(wrappedValue: "hello"),
        isCodedAs: """
          "hello"
          """
      )
    }

    @Test
    func testNestedStruct() throws {
      try test(
        NestedStruct(inner: SimpleStruct(name: "Bob", age: 25)),
        isCodedAs: """
          {
            "inner": {
              "name": "Bob",
              "age": 25
            }
          }
          """
      )
    }

    @Test
    func testStructWithArray() throws {
      try test(
        StructWithArray(items: ["a", "b", "c"]),
        isCodedAs: """
          {
            "items": [
              "a",
              "b",
              "c"
            ]
          }
          """
      )
    }

    @Test
    func testMultipleOptionalsAllPresent() throws {
      try test(
        MultipleOptionals(first: "hello", second: 42, third: true),
        isCodedAs: """
          {
            "first": "hello",
            "second": 42,
            "third": true
          }
          """
      )
    }

    @Test
    func testMultipleOptionalsAllNil() throws {
      try test(
        MultipleOptionals(first: nil, second: nil, third: nil),
        isCodedAs: """
          {

          }
          """
      )
    }

    @Test
    func testMultipleOptionalsPartial() throws {
      try test(
        MultipleOptionals(first: "hello", second: nil, third: true),
        isCodedAs: """
          {
            "first": "hello",
            "third": true
          }
          """
      )
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testSimpleStructMetaSchema() throws {
      try SimpleStruct.schema.test(
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
          """
      )
    }

    @Test
    func testDescribedStructMetaSchema() throws {
      try DescribedStruct.schema.test(
        encodesAs: """
          {
            "description": "A person with a name",
            "properties": {
              "name": {
                "type": "string"
              }
            },
            "required": [
              "name"
            ]
          }
          """
      )
    }

    @Test
    func testStructWithOptionalMetaSchema() throws {
      try StructWithOptional.schema.test(
        encodesAs: """
          {
            "properties": {
              "required": {
                "type": "string"
              },
              "optional": {
                "type": "integer"
              }
            },
            "required": [
              "required"
            ]
          }
          """
      )
    }

    @Test
    func testWrapperStructMetaSchema() throws {
      try WrapperStruct.schema.test(
        encodesAs: """
          {
            "type": "string"
          }
          """
      )
    }

  }

}

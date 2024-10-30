import XCTest

@testable import ClaudeToolInput

final class EnumTests: XCTestCase {

  func testEnumSchema() async throws {
    XCTAssertEqual(
      try encode(TestEnum.toolInputSchema),
      """
      {
        "additionalProperties" : false,
        "maxProperties" : 1,
        "minProperties" : 1,
        "properties" : {
          "bool" : {
            "type" : "boolean"
          },
          "tuple" : {
            "additionalProperties" : false,
            "properties" : {
              "_0" : {
                "type" : "boolean"
              },
              "second" : {
                "type" : "boolean"
              }
            },
            "required" : [
              "_0",
              "second"
            ],
            "type" : "object"
          },
          "void" : {
            "additionalProperties" : false,
            "type" : "object"
          }
        },
        "type" : "object"
      }
      """
    )

    XCTAssertEqual(
      try encode(TestEnum.toolInputSchema) { schema in
        schema.description = "A test sum type"
      },
      """
      {
        "additionalProperties" : false,
        "description" : "A test sum type",
        "maxProperties" : 1,
        "minProperties" : 1,
        "properties" : {
          "bool" : {
            "type" : "boolean"
          },
          "tuple" : {
            "additionalProperties" : false,
            "properties" : {
              "_0" : {
                "type" : "boolean"
              },
              "second" : {
                "type" : "boolean"
              }
            },
            "required" : [
              "_0",
              "second"
            ],
            "type" : "object"
          },
          "void" : {
            "additionalProperties" : false,
            "type" : "object"
          }
        },
        "type" : "object"
      }
      """
    )
  }

  func testEnumEncoding() async throws {
    XCTAssertEqual(
      try encode(TestEnum.void),
      """
      {
        "void" : {

        }
      }
      """
    )

    XCTAssertEqual(
      try encode(TestEnum.single(true)),
      """
      {
        "bool" : true
      }
      """
    )

    XCTAssertEqual(
      try encode(TestEnum.tuple(true, second: false)),
      """
      {
        "tuple" : {
          "_0" : true,
          "second" : false
        }
      }
      """
    )
  }

  func testEnumDecoding() async throws {
    XCTAssertEqual(
      try decode(
        TestEnum.self,
        """
        {
          "void" : {

          }
        }
        """
      ),
      TestEnum.void
    )

    XCTAssertEqual(
      try decode(
        TestEnum.self,
        """
        {
          "bool" : true
        }
        """
      ),
      TestEnum.single(true)
    )

    XCTAssertEqual(
      try decode(
        TestEnum.self,
        """
        {
          "tuple" : {
            "_0" : true,
            "second" : false
          }
        }
        """
      ),
      TestEnum.tuple(true, second: false)
    )

    XCTAssertThrowsError(
      try decode(
        TestEnum.self,
        """
        {
          "unknown" : "value"
        }
        """
      )
    )
  }
}

private enum TestEnum: ToolInput, Equatable {
  case void
  case single(Bool)
  case tuple(Bool, second: Bool)

  typealias ToolInputSchema = ToolInputEnumSchema<
    ToolInputVoidSchema,
    Bool.ToolInputSchema,
    ToolInputKeyedTupleSchema<
      Bool.ToolInputSchema,
      Bool.ToolInputSchema
    >
  >
  static var toolInputSchema: ToolInputSchema {
    ToolInputEnumSchema(
      (
        ToolInputSchemaKey("void"),
        ToolInputVoidSchema()
      ),
      (
        ToolInputSchemaKey("bool"),
        Bool.toolInputSchema
      ),
      (
        ToolInputSchemaKey("tuple"),
        ToolInputKeyedTupleSchema(
          (
            ToolInputSchemaKey("_0"),
            Bool.toolInputSchema
          ),
          (
            ToolInputSchemaKey("second"),
            Bool.toolInputSchema
          )
        )
      )
    )
  }

  init(toolInputSchemaDescribedValue value: ToolInputSchema.DescribedValue) {
    switch value {
    case (.some(_), _, _):
      self = .void
    case let (_, .some(bool), _):
      self = .single(bool)
    case let (_, _, .some(tuple)):
      self = .tuple(tuple.0, second: tuple.1)
    default:
      fatalError()
    }
  }

  var toolInputSchemaDescribedValue: ToolInputSchema.DescribedValue {
    switch self {
    case .void:
      return (.some(()), .none, .none)
    case .single(let value):
      return (.none, .some(value), .none)
    case let .tuple(value_0, value_1):
      return (.none, .none, .some((value_0, value_1)))
    }
  }
}

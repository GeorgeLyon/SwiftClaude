import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Enum Schema Protocol")
struct EnumSchemaProtocolTests {

  @Test
  func testCasesWithNoAssociatedValues() throws {
    enum NoAssociatedValues: Equatable {
      case first
      case second

      typealias ValueSelf = Self
      struct Schema: SchemaCoding.Support.EnumSchemaProtocol {

        typealias Value = ValueSelf

        @SchemaCoding.Support.EnumSchemaCasesBuilder<ValueSelf>
        static var cases:
          SchemaCoding.Support.EnumSchemaCases<
            Value,
            SchemaCoding.Support.ConcreteObjectSchema<
              SchemaCoding.Support.TupleObjectSchemaProperties<
              >
            >,
            SchemaCoding.Support.ConcreteObjectSchema<
              SchemaCoding.Support.TupleObjectSchemaProperties<
              >
            >
          >
        {
          SchemaCoding.Support.enumSchemaCase(
            name: "first",
            associatedValues: {

            },
            finishDecoding: { decoder in
              Value.first
            }
          )
          SchemaCoding.Support.enumSchemaCase(
            name: "second",
            associatedValues: {

            },
            finishDecoding: { decoder in
              Value.second
            }
          )
        }

        static func encodeValue(
          _ value: Value,
          to encoder:
            inout SchemaCoding.Support.EnumSchemaEncoder<
              SchemaCoding.Support.ConcreteObjectSchema<
                SchemaCoding.Support.TupleObjectSchemaProperties<
                >
              >,
              SchemaCoding.Support.ConcreteObjectSchema<
                SchemaCoding.Support.TupleObjectSchemaProperties<
                >
              >
            >
        ) {
          switch value {
          case .first:
            encoder.encode((), using: encoder.encodings.0)
          case .second:
            encoder.encode((), using: encoder.encodings.1)
          }
        }

      }

    }
  }

}

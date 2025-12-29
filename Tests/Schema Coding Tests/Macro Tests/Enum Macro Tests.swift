import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Enum Macro")
struct EnumMacroTests {

  @SchemaCodable
  fileprivate enum SimpleEnum: Equatable {
    case first
    case second
  }

  @SchemaCodable
  fileprivate enum EnumWithAssociatedValue: Equatable {
    case alpha(Int)
    case beta(String)
  }

  @SchemaCodable
  fileprivate enum EnumWithLabeledAssociatedValues: Equatable {
    case point(x: Int, y: Int)
    case origin
  }

  @SchemaCodable
  fileprivate enum SingleCaseEnum: Equatable {
    case only
  }

  @SchemaCodable
  fileprivate enum SingleCaseEnumWithValue: Equatable {
    case value(Int)
  }

  @SchemaCodable(description: "A status enum")
  fileprivate enum DescribedEnum: Equatable {
    case active
    case inactive
  }

  @SchemaCodable
  fileprivate enum EnumWithOptionalValue: Equatable {
    case some(value: String?)
    case none
  }

  @SchemaCodable
  fileprivate enum EnumWithNestedType: Equatable {
    case nested(EnumMacroTests.SimpleEnum)
    case plain
  }

  @Suite("Coding")
  struct CodingTests {

    @Test
    func testSimpleEnumFirstCase() throws {
      try test(
        SimpleEnum.first,
        isCodedAs: """
          {
            "first": {

            }
          }
          """
      )
    }

    @Test
    func testSimpleEnumSecondCase() throws {
      try test(
        SimpleEnum.second,
        isCodedAs: """
          {
            "second": {

            }
          }
          """
      )
    }

    @Test
    func testEnumWithAssociatedValueAlpha() throws {
      try test(
        EnumWithAssociatedValue.alpha(42),
        isCodedAs: """
          {
            "alpha": 42
          }
          """
      )
    }

    @Test
    func testEnumWithAssociatedValueBeta() throws {
      try test(
        EnumWithAssociatedValue.beta("hello"),
        isCodedAs: """
          {
            "beta": "hello"
          }
          """
      )
    }

    @Test
    func testEnumWithLabeledAssociatedValuesPoint() throws {
      try test(
        EnumWithLabeledAssociatedValues.point(x: 10, y: 20),
        isCodedAs: """
          {
            "point": {
              "x": 10,
              "y": 20
            }
          }
          """
      )
    }

    @Test
    func testEnumWithLabeledAssociatedValuesOrigin() throws {
      try test(
        EnumWithLabeledAssociatedValues.origin,
        isCodedAs: """
          {
            "origin": {

            }
          }
          """
      )
    }

    @Test
    func testSingleCaseEnum() throws {
      try test(
        SingleCaseEnum.only,
        isCodedAs: """
          {
            "only": {

            }
          }
          """
      )
    }

    @Test
    func testSingleCaseEnumWithValue() throws {
      try test(
        SingleCaseEnumWithValue.value(42),
        isCodedAs: """
          {
            "value": 42
          }
          """
      )
    }

    @Test
    func testEnumWithOptionalValuePresent() throws {
      try test(
        EnumWithOptionalValue.some(value: "hello"),
        isCodedAs: """
          {
            "some": {
              "value": "hello"
            }
          }
          """
      )
    }

    @Test
    func testEnumWithOptionalValueNil() throws {
      try test(
        EnumWithOptionalValue.some(value: nil),
        isCodedAs: """
          {
            "some": {

            }
          }
          """
      )
    }

    @Test
    func testEnumWithOptionalValueNoneCase() throws {
      try test(
        EnumWithOptionalValue.none,
        isCodedAs: """
          {
            "none": {

            }
          }
          """
      )
    }

    @Test
    func testEnumWithNestedTypeNested() throws {
      try test(
        EnumWithNestedType.nested(.first),
        isCodedAs: """
          {
            "nested": {
              "first": {

              }
            }
          }
          """
      )
    }

    @Test
    func testEnumWithNestedTypePlain() throws {
      try test(
        EnumWithNestedType.plain,
        isCodedAs: """
          {
            "plain": {

            }
          }
          """
      )
    }

  }

  @Suite("Meta Schema")
  struct MetaSchemaTests {

    @Test
    func testSimpleEnumMetaSchema() throws {
      try SimpleEnum.schema.test(
        encodesAs: """
          {
            "properties": {
              "first": {
                "properties": {

                }
              },
              "second": {
                "properties": {

                }
              }
            }
          }
          """
      )
    }

    @Test
    func testDescribedEnumMetaSchema() throws {
      try DescribedEnum.schema.test(
        encodesAs: """
          {
            "description": "A status enum",
            "properties": {
              "active": {
                "properties": {

                }
              },
              "inactive": {
                "properties": {

                }
              }
            }
          }
          """
      )
    }

    @Test
    func testSingleCaseEnumMetaSchema() throws {
      try SingleCaseEnum.schema.test(
        encodesAs: """
          {
            "properties": {
              "only": {
                "properties": {

                }
              }
            }
          }
          """
      )
    }

    @Test
    func testSingleCaseEnumWithValueMetaSchema() throws {
      try SingleCaseEnumWithValue.schema.test(
        encodesAs: """
          {
            "properties": {
              "value": {
                "type": "integer"
              }
            }
          }
          """
      )
    }

    @Test
    func testEnumWithAssociatedValueMetaSchema() throws {
      try EnumWithAssociatedValue.schema.test(
        encodesAs: """
          {
            "properties": {
              "alpha": {
                "type": "integer"
              },
              "beta": {
                "type": "string"
              }
            }
          }
          """
      )
    }

  }

}

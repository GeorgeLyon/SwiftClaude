import SchemaCodingTestSupport
import Testing

@testable import SchemaCoding

@Suite("Enum Schema")
struct EnumSchemaTests {

  @Suite("Standard Style")
  struct StandardStyleTests {

    @Suite("Coding")
    struct CodingTests {

      @Test
      func testCasesWithNoAssociatedValues() throws {
        enum SimpleEnum: Equatable {
          case first
          case second
        }

        let firstCase = SchemaCoding.Support.enumSchemaCase(
          name: "first",
          associatedValues: {},
          finishDecoding: { _ in SimpleEnum.first }
        )
        let secondCase = SchemaCoding.Support.enumSchemaCase(
          name: "second",
          associatedValues: {},
          finishDecoding: { _ in SimpleEnum.second }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: SimpleEnum.self,
          cases: {
            firstCase
            secondCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .first:
              encoder.encode((), using: encoder.encodings.0)
            case .second:
              encoder.encode((), using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          SimpleEnum.first,
          isCodedAs: #"""
            {
              "first": {

              }
            }
            """#
        )
        try schema.test(
          SimpleEnum.second,
          isCodedAs: #"""
            {
              "second": {

              }
            }
            """#
        )
      }

      @Test
      func testCasesWithSingleUnlabeledAssociatedValue() throws {
        enum IntEnum: Equatable {
          case alpha(Int)
          case beta(String)
        }

        let alphaCase = SchemaCoding.Support.enumSchemaCase(
          name: "alpha",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<Int>) in
            IntEnum.alpha(decoder.associatedValues.0)
          }
        )
        let betaCase = SchemaCoding.Support.enumSchemaCase(
          name: "beta",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<String>) in
            IntEnum.beta(decoder.associatedValues.0)
          }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: IntEnum.self,
          cases: {
            alphaCase
            betaCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .alpha(let v):
              encoder.encode(v, using: encoder.encodings.0)
            case .beta(let v):
              encoder.encode(v, using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          IntEnum.alpha(42),
          isCodedAs: #"""
            {
              "alpha": 42
            }
            """#
        )
        try schema.test(
          IntEnum.beta("hello"),
          isCodedAs: #"""
            {
              "beta": "hello"
            }
            """#
        )
      }

      @Test
      func testCasesWithLabeledAssociatedValues() throws {
        enum PointEnum: Equatable {
          case point(x: Int, y: Int)
          case origin
        }

        let pointCase = SchemaCoding.Support.enumSchemaCase(
          name: "point",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "x",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "y",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumCaseDecoder<Int, Int>) in
            PointEnum.point(x: decoder.associatedValues.0, y: decoder.associatedValues.1)
          }
        )
        let originCase = SchemaCoding.Support.enumSchemaCase(
          name: "origin",
          associatedValues: {},
          finishDecoding: { _ in PointEnum.origin }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: PointEnum.self,
          cases: {
            pointCase
            originCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .point(let x, let y):
              encoder.encode((x, y), using: encoder.encodings.0)
            case .origin:
              encoder.encode((), using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          PointEnum.point(x: 10, y: 20),
          isCodedAs: #"""
            {
              "point": {
                "x": 10,
                "y": 20
              }
            }
            """#
        )
        try schema.test(
          PointEnum.origin,
          isCodedAs: #"""
            {
              "origin": {

              }
            }
            """#
        )
      }

      @Test
      func testSingleCaseEnumWithNoAssociatedValues() throws {
        enum SingleCaseEnum: Equatable {
          case only
        }

        let onlyCase = SchemaCoding.Support.enumSchemaCase(
          name: "only",
          associatedValues: {},
          finishDecoding: { _ in SingleCaseEnum.only }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: SingleCaseEnum.self,
          cases: {
            onlyCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .only:
              encoder.encode((), using: encoder.encodings.0)
            }
          }
        )

        try schema.test(
          SingleCaseEnum.only,
          isCodedAs: #"""
            {
              "only": {

              }
            }
            """#
        )
      }

      @Test
      func testSingleCaseEnumWithAssociatedValue() throws {
        enum SingleValueEnum: Equatable {
          case value(Int)
        }

        let valueCase = SchemaCoding.Support.enumSchemaCase(
          name: "value",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<Int>) in
            SingleValueEnum.value(decoder.associatedValues.0)
          }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: SingleValueEnum.self,
          cases: {
            valueCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .value(let v):
              encoder.encode(v, using: encoder.encodings.0)
            }
          }
        )

        try schema.test(
          SingleValueEnum.value(42),
          isCodedAs: #"""
            {
              "value": 42
            }
            """#
        )
      }

      @Test
      func testCasesWithMultipleUnlabeledAssociatedValues() throws {
        enum TupleEnum: Equatable {
          case pair(Int, Bool)
          case single
        }

        let pairCase = SchemaCoding.Support.enumSchemaCase(
          name: "pair",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              schema: SchemaCoding.Support.BooleanSchema()
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumCaseDecoder<Int, Bool>) in
            TupleEnum.pair(decoder.associatedValues.0, decoder.associatedValues.1)
          }
        )
        let singleCase = SchemaCoding.Support.enumSchemaCase(
          name: "single",
          associatedValues: {},
          finishDecoding: { _ in TupleEnum.single }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: TupleEnum.self,
          cases: {
            pairCase
            singleCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .pair(let i, let b):
              encoder.encode((i, b), using: encoder.encodings.0)
            case .single:
              encoder.encode((), using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          TupleEnum.pair(42, true),
          isCodedAs: #"""
            {
              "pair": [
                42,
                true
              ]
            }
            """#
        )
        try schema.test(
          TupleEnum.single,
          isCodedAs: #"""
            {
              "single": {

              }
            }
            """#
        )
      }

    }

    @Suite("Meta Schema")
    struct MetaSchemaTests {

      @Test
      func testEnumMetaSchema() throws {
        enum TestEnum: Equatable {
          case alpha
          case beta
        }

        let alphaCase = SchemaCoding.Support.enumSchemaCase(
          name: "alpha",
          associatedValues: {},
          finishDecoding: { _ in TestEnum.alpha }
        )
        let betaCase = SchemaCoding.Support.enumSchemaCase(
          name: "beta",
          associatedValues: {},
          finishDecoding: { _ in TestEnum.beta }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: TestEnum.self,
          cases: {
            alphaCase
            betaCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .alpha:
              encoder.encode((), using: encoder.encodings.0)
            case .beta:
              encoder.encode((), using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          encodesAs: """
            {
              "properties": {
                "alpha": {
                  "properties": {

                  }
                },
                "beta": {
                  "properties": {

                  }
                }
              }
            }
            """
        )
      }

    }

  }

  @Suite("Internally Tagged Style")
  struct InternallyTaggedStyleTests {

    @Suite("Coding")
    struct CodingTests {

      @Test
      func testCasesWithNoAssociatedValues() throws {
        enum TaggedEnum: Equatable {
          case first
          case second
        }

        let firstCase = SchemaCoding.Support.enumSchemaCase(
          name: "first",
          associatedValues: {},
          finishDecoding: { _ in TaggedEnum.first }
        )
        let secondCase = SchemaCoding.Support.enumSchemaCase(
          name: "second",
          associatedValues: {},
          finishDecoding: { _ in TaggedEnum.second }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: TaggedEnum.self,
          style: .internallyTagged(discriminatorPropertyName: "type"),
          cases: {
            firstCase
            secondCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .first:
              encoder.encode((), using: encoder.encodings.0)
            case .second:
              encoder.encode((), using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          TaggedEnum.first,
          isCodedAs: """
            {
              "type": "first"
            }
            """
        )
        try schema.test(
          TaggedEnum.second,
          isCodedAs: """
            {
              "type": "second"
            }
            """
        )
      }

      @Test
      func testCasesWithLabeledAssociatedValue() throws {
        enum ContentEnum: Equatable {
          case text(content: String)
          case number(value: Int)
        }

        let textCase = SchemaCoding.Support.enumSchemaCase(
          name: "text",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "content",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<String>) in
            ContentEnum.text(content: decoder.associatedValues.0)
          }
        )
        let numberCase = SchemaCoding.Support.enumSchemaCase(
          name: "number",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "value",
              schema: SchemaCoding.Support.schema(representing: Int.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<Int>) in
            ContentEnum.number(value: decoder.associatedValues.0)
          }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: ContentEnum.self,
          style: .internallyTagged(discriminatorPropertyName: "kind"),
          cases: {
            textCase
            numberCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .text(let content):
              encoder.encode(content, using: encoder.encodings.0)
            case .number(let value):
              encoder.encode(value, using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          ContentEnum.text(content: "hello"),
          isCodedAs: """
            {
              "kind": "text",
              "content": "hello"
            }
            """
        )
        try schema.test(
          ContentEnum.number(value: 42),
          isCodedAs: """
            {
              "kind": "number",
              "value": 42
            }
            """
        )
      }

      @Test
      func testSingleCaseEnumWithNoAssociatedValues() throws {
        enum SingleTaggedEnum: Equatable {
          case only
        }

        let onlyCase = SchemaCoding.Support.enumSchemaCase(
          name: "only",
          associatedValues: {},
          finishDecoding: { _ in SingleTaggedEnum.only }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: SingleTaggedEnum.self,
          style: .internallyTagged(discriminatorPropertyName: "type"),
          cases: {
            onlyCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .only:
              encoder.encode((), using: encoder.encodings.0)
            }
          }
        )

        try schema.test(
          SingleTaggedEnum.only,
          isCodedAs: """
            {
              "type": "only"
            }
            """
        )
      }

      @Test
      func testSingleCaseEnumWithLabeledAssociatedValue() throws {
        enum SingleContentEnum: Equatable {
          case data(content: String)
        }

        let dataCase = SchemaCoding.Support.enumSchemaCase(
          name: "data",
          associatedValues: {
            SchemaCoding.Support.enumSchemaCaseAssociatedValue(
              label: "content",
              schema: SchemaCoding.Support.schema(representing: String.self)
            )
          },
          finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<String>) in
            SingleContentEnum.data(content: decoder.associatedValues.0)
          }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: SingleContentEnum.self,
          style: .internallyTagged(discriminatorPropertyName: "kind"),
          cases: {
            dataCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .data(let content):
              encoder.encode(content, using: encoder.encodings.0)
            }
          }
        )

        try schema.test(
          SingleContentEnum.data(content: "hello"),
          isCodedAs: """
            {
              "kind": "data",
              "content": "hello"
            }
            """
        )
      }

    }

    @Suite("Meta Schema")
    struct MetaSchemaTests {

      @Test
      func testInternallyTaggedEnumMetaSchema() throws {
        enum TaggedEnum: Equatable {
          case alpha
          case beta
        }

        let alphaCase = SchemaCoding.Support.enumSchemaCase(
          name: "alpha",
          associatedValues: {},
          finishDecoding: { _ in TaggedEnum.alpha }
        )
        let betaCase = SchemaCoding.Support.enumSchemaCase(
          name: "beta",
          associatedValues: {},
          finishDecoding: { _ in TaggedEnum.beta }
        )

        let schema = SchemaCoding.Support.enumSchema(
          representing: TaggedEnum.self,
          style: .internallyTagged(discriminatorPropertyName: "type"),
          cases: {
            alphaCase
            betaCase
          },
          encodeValue: { value, encoder in
            switch value {
            case .alpha:
              encoder.encode((), using: encoder.encodings.0)
            case .beta:
              encoder.encode((), using: encoder.encodings.1)
            }
          }
        )

        try schema.test(
          encodesAs: """
            {
              "oneOf": [
                {
                  "properties": {
                    "type": {
                      "const": "alpha"
                    }
                  },
                  "required": [
                    "type"
                  ]
                },
                {
                  "properties": {
                    "type": {
                      "const": "beta"
                    }
                  },
                  "required": [
                    "type"
                  ]
                }
              ]
            }
            """
        )
      }

    }

  }

}

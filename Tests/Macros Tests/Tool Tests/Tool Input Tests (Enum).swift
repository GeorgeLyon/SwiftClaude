import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@ToolInput Enum")
struct ToolInputEnumTests {

  @Test
  func testEnumMacro() {

    assertMacroExpansion(
      """
      @ToolInput(
        description: "A Tool Input Enum"
      )
      enum ToolInputEnum {
        case `simple`

        @SchemaCase(
          description: "A case with a single associated value"
        )
        case singleAssociatedValue(Int)

        @SchemaCase(
          description: "Multiple associated values without a name"
        )
        case mutlipleUnnamedAssociatedValues(Int, String)

        @SchemaCase(
          description: "Multiple associated values with a name"
        )
        case multipleNamedAssociatedValues(a: Int, b: String, c: Bool)

        @SchemaCase(
          description: "Multiple associated values with some named and some unnamed"
        )
        case mixedAssociatedValues(Int, b: String, c: Bool)
      }
      """,
      expandedSource: #####"""
        enum ToolInputEnum {
          case `simple`
          case singleAssociatedValue(Int)
          case mutlipleUnnamedAssociatedValues(Int, String)
          case multipleNamedAssociatedValues(a: Int, b: String, c: Bool)
          case mixedAssociatedValues(Int, b: String, c: Bool)
        }

        extension ToolInputEnum: ToolInput.SchemaCodable {
          static var schema: some ToolInput.Schema<Self> & ToolInput.Support.ComplexSchema {
            ToolInput.Support.enumSchema(
              description: "A Tool Input Enum",
              cases: {
                ToolInput.Support.enumSchemaCase(
                  name: "simple",
                  associatedValues: {
                  },
                  finishDecoding: { (decoder: ToolInput.EnumCaseDecoder< >) in
                    Self.`simple`
                  }
                )
                ToolInput.Support.enumSchemaCase(
                  name: "singleAssociatedValue",
                  description: "A case with a single associated value",
                  associatedValues: {
                    ToolInput.Support.parameter(
                      schema: ToolInput.Support.schema(
                        representing: Int.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: ToolInput.EnumSingleAssociatedValueCaseDecoder<Int>) in
                    Self.singleAssociatedValue(
                      decoder.associatedValues.0
                    )
                  }
                )
                ToolInput.Support.enumSchemaCase(
                  name: "mutlipleUnnamedAssociatedValues",
                  description: "Multiple associated values without a name",
                  associatedValues: {
                    ToolInput.Support.parameter(
                      schema: ToolInput.Support.schema(
                        representing: Int.self
                      )
                    )
                    ToolInput.Support.parameter(
                      schema: ToolInput.Support.schema(
                        representing: String.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: ToolInput.EnumCaseDecoder<Int, String>) in
                    Self.mutlipleUnnamedAssociatedValues(
                      decoder.associatedValues.0, decoder.associatedValues.1
                    )
                  }
                )
                ToolInput.Support.enumSchemaCase(
                  name: "multipleNamedAssociatedValues",
                  description: "Multiple associated values with a name",
                  associatedValues: {
                    ToolInput.Support.parameter(
                      label: "a",
                      schema: ToolInput.Support.schema(
                        representing: Int.self
                      )
                    )
                    ToolInput.Support.parameter(
                      label: "b",
                      schema: ToolInput.Support.schema(
                        representing: String.self
                      )
                    )
                    ToolInput.Support.parameter(
                      label: "c",
                      schema: ToolInput.Support.schema(
                        representing: Bool.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: ToolInput.EnumCaseDecoder<Int, String, Bool>) in
                    Self.multipleNamedAssociatedValues(
                      a: decoder.associatedValues.0, b: decoder.associatedValues.1, c: decoder.associatedValues.2
                    )
                  }
                )
                ToolInput.Support.enumSchemaCase(
                  name: "mixedAssociatedValues",
                  description: "Multiple associated values with some named and some unnamed",
                  associatedValues: {
                    ToolInput.Support.parameter(
                      schema: ToolInput.Support.schema(
                        representing: Int.self
                      )
                    )
                    ToolInput.Support.parameter(
                      label: "b",
                      schema: ToolInput.Support.schema(
                        representing: String.self
                      )
                    )
                    ToolInput.Support.parameter(
                      label: "c",
                      schema: ToolInput.Support.schema(
                        representing: Bool.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: ToolInput.EnumCaseDecoder<Int, String, Bool>) in
                    Self.mixedAssociatedValues(
                      decoder.associatedValues.0, b: decoder.associatedValues.1, c: decoder.associatedValues.2
                    )
                  }
                )
              },
              encodeValue: { value, encoder in
                switch value {
                case .simple:
                  encoder.encode((), using: encoder.encodings.0)
                case .singleAssociatedValue(let __value_0):
                  encoder.encode((__value_0), using: encoder.encodings.1)
                case .mutlipleUnnamedAssociatedValues(let __value_0, let __value_1):
                  encoder.encode((__value_0, __value_1), using: encoder.encodings.2)
                case .multipleNamedAssociatedValues(let __value_0, let __value_1, let __value_2):
                  encoder.encode((__value_0, __value_1, __value_2), using: encoder.encodings.3)
                case .mixedAssociatedValues(let __value_0, let __value_1, let __value_2):
                  encoder.encode((__value_0, __value_1, __value_2), using: encoder.encodings.4)
                }
              }
            )
          }
        }
        """#####,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2),
      failureHandler: {
        Issue.record(
          "\($0.message)",
          sourceLocation: SourceLocation(
            fileID: $0.location.fileID,
            filePath: $0.location.filePath,
            line: $0.location.line,
            column: $0.location.column
          )
        )
      }
    )
  }

  private let macroSpecs = [
    "ToolInput": MacroSpec(type: ToolInputMacro.self),
    "SchemaCase": MacroSpec(type: SchemaCaseMacro.self),
  ]
}

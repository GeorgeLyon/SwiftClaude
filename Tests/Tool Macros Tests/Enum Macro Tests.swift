import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import ToolMacros

@Suite("Enum")
private struct EnumMacroTests {

  @Test
  func testEnumMacro() {

    assertMacroExpansion(
      """
      @ToolInput
      enum ToolInputEnum {
        case simple
        /// A case with a single associated value
        case singleAssociatedValue(Int)
        // Multiple associated values without a name
        case mutlipleUnnamedAssociatedValues(Int, String)
        // Multiple associated values with a name
        case multipleNamedAssociatedValues(a: Int, b: String, c: Bool)
        // Multiple associated values with some named and some unnamed
        case mixedAssociatedValues(Int, b: String, c: Bool)
      }
      """,
      expandedSource: #"""
        enum ToolInputEnum {
          case simple
          /// A case with a single associated value
          case singleAssociatedValue(Int)
          // Multiple associated values without a name
          case mutlipleUnnamedAssociatedValues(Int, String)
          // Multiple associated values with a name
          case multipleNamedAssociatedValues(a: Int, b: String, c: Bool)
          // Multiple associated values with some named and some unnamed
          case mixedAssociatedValues(Int, b: String, c: Bool)
        }

        extension ToolInputEnum: ToolInput.SchemaCodable {
          static var toolInputSchema: some ToolInput.Schema<Self> {
            let simpleAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (

              ), keyedBy: ToolInputSchemaCaseKey.AssociatedValuesKey_simple.self
            )
            let singleAssociatedValueAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_singleAssociatedValue?.none,
                  schema: ToolInput.schema(representing: Int.self)
                )
              ), keyedBy: ToolInputSchemaCaseKey.AssociatedValuesKey_singleAssociatedValue.self
            )
            let mutlipleUnnamedAssociatedValuesAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_mutlipleUnnamedAssociatedValues?.none,
                  schema: ToolInput.schema(representing: Int.self)
                ), (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_mutlipleUnnamedAssociatedValues?.none,
                  schema: ToolInput.schema(representing: String.self)
                )
              ), keyedBy: ToolInputSchemaCaseKey.AssociatedValuesKey_mutlipleUnnamedAssociatedValues.self
            )
            let multipleNamedAssociatedValuesAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_multipleNamedAssociatedValues.a,
                  schema: ToolInput.schema(representing: Int.self)
                ), (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_multipleNamedAssociatedValues.b,
                  schema: ToolInput.schema(representing: String.self)
                ), (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_multipleNamedAssociatedValues.c,
                  schema: ToolInput.schema(representing: Bool.self)
                )
              ), keyedBy: ToolInputSchemaCaseKey.AssociatedValuesKey_multipleNamedAssociatedValues.self
            )
            let mixedAssociatedValuesAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_mixedAssociatedValues?.none,
                  schema: ToolInput.schema(representing: Int.self)
                ), (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_mixedAssociatedValues.b,
                  schema: ToolInput.schema(representing: String.self)
                ), (
                  key: ToolInputSchemaCaseKey.AssociatedValuesKey_mixedAssociatedValues.c,
                  schema: ToolInput.schema(representing: Bool.self)
                )
              ), keyedBy: ToolInputSchemaCaseKey.AssociatedValuesKey_mixedAssociatedValues.self
            )
            return ToolInput.enumSchema(
              representing: Self.self,
              description: nil,
              keyedBy: ToolInputSchemaCaseKey.self,
              cases: (
                (
                  key: ToolInputSchemaCaseKey.simple,
                  description: nil,
                  associatedValuesSchema: simpleAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .simple
                  }
                ),
                (
                  key: ToolInputSchemaCaseKey.singleAssociatedValue,
                  description: """
                  A case with a single associated value
                  """,
                  associatedValuesSchema: singleAssociatedValueAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .singleAssociatedValue(values)
                  }
                ),
                (
                  key: ToolInputSchemaCaseKey.mutlipleUnnamedAssociatedValues,
                  description: """
                  Multiple associated values without a name
                  """,
                  associatedValuesSchema: mutlipleUnnamedAssociatedValuesAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .mutlipleUnnamedAssociatedValues(values.0, values.1)
                  }
                ),
                (
                  key: ToolInputSchemaCaseKey.multipleNamedAssociatedValues,
                  description: """
                  Multiple associated values with a name
                  """,
                  associatedValuesSchema: multipleNamedAssociatedValuesAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .multipleNamedAssociatedValues(a: values.0, b: values.1, c: values.2)
                  }
                ),
                (
                  key: ToolInputSchemaCaseKey.mixedAssociatedValues,
                  description: """
                  Multiple associated values with some named and some unnamed
                  """,
                  associatedValuesSchema: mixedAssociatedValuesAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .mixedAssociatedValues(values.0, b: values.1, c: values.2)
                  }
                )
              ),
              encodeValue: { @Sendable value, simpleEncoder, singleAssociatedValueEncoder, mutlipleUnnamedAssociatedValuesEncoder, multipleNamedAssociatedValuesEncoder, mixedAssociatedValuesEncoder in
                switch value {
                case .simple:
                  try simpleEncoder(())
                case .singleAssociatedValue(let _0):
                  try singleAssociatedValueEncoder((_0))
                case .mutlipleUnnamedAssociatedValues(let _0, let _1):
                  try mutlipleUnnamedAssociatedValuesEncoder((_0, _1))
                case .multipleNamedAssociatedValues(let a, let b, let c):
                  try multipleNamedAssociatedValuesEncoder((a, b, c))
                case .mixedAssociatedValues(let _0, let b, let c):
                  try mixedAssociatedValuesEncoder((_0, b, c))
                }
              }
            )
          }
          private enum ToolInputSchemaCaseKey: Swift.CodingKey {
            case simple
            case singleAssociatedValue
            private enum AssociatedValuesKey_singleAssociatedValue: Swift.CodingKey {
            }
            case mutlipleUnnamedAssociatedValues
            private enum AssociatedValuesKey_mutlipleUnnamedAssociatedValues: Swift.CodingKey {
            }
            case multipleNamedAssociatedValues
            private enum AssociatedValuesKey_multipleNamedAssociatedValues: Swift.CodingKey {
              case a
              case b
              case c
            }
            case mixedAssociatedValues
            private enum AssociatedValuesKey_mixedAssociatedValues: Swift.CodingKey {
              case b
              case c
            }
          }
        }
        """#,
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
    "ToolInput": MacroSpec(type: ToolInputMacro.self)
  ]
}

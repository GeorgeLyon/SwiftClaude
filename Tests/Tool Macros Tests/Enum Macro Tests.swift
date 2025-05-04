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
      expandedSource: ##"""
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

              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_simple.self
            )
            let singleAssociatedValueAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_singleAssociatedValue?.none,
                  schema: ToolInput.schema(representing: Int.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_singleAssociatedValue.self
            )
            let mutlipleUnnamedAssociatedValuesAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_mutlipleUnnamedAssociatedValues?.none,
                  schema: ToolInput.schema(representing: Int.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_mutlipleUnnamedAssociatedValues?.none,
                  schema: ToolInput.schema(representing: String.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_mutlipleUnnamedAssociatedValues.self
            )
            let multipleNamedAssociatedValuesAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_multipleNamedAssociatedValues.a,
                  schema: ToolInput.schema(representing: Int.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_multipleNamedAssociatedValues.b,
                  schema: ToolInput.schema(representing: String.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_multipleNamedAssociatedValues.c,
                  schema: ToolInput.schema(representing: Bool.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_multipleNamedAssociatedValues.self
            )
            let mixedAssociatedValuesAssociatedValuesSchema = ToolInput.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_mixedAssociatedValues?.none,
                  schema: ToolInput.schema(representing: Int.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_mixedAssociatedValues.b,
                  schema: ToolInput.schema(representing: String.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_mixedAssociatedValues.c,
                  schema: ToolInput.schema(representing: Bool.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey_mixedAssociatedValues.self
            )
            return ToolInput.enumSchema(
              representing: Self.self,
              description: nil,
              keyedBy: __macro_local_7CaseKeyfMu_.self,
              cases: (
                (
                  key: __macro_local_7CaseKeyfMu_.simple,
                  description: nil,
                  associatedValuesSchema: simpleAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .simple
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.singleAssociatedValue,
                  description: #"""
                  A case with a single associated value
                  """#,
                  associatedValuesSchema: singleAssociatedValueAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .singleAssociatedValue(values)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.mutlipleUnnamedAssociatedValues,
                  description: #"""
                  Multiple associated values without a name
                  """#,
                  associatedValuesSchema: mutlipleUnnamedAssociatedValuesAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .mutlipleUnnamedAssociatedValues(values.0, values.1)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.multipleNamedAssociatedValues,
                  description: #"""
                  Multiple associated values with a name
                  """#,
                  associatedValuesSchema: multipleNamedAssociatedValuesAssociatedValuesSchema,
                  initializer: { @Sendable values in
                    .multipleNamedAssociatedValues(a: values.0, b: values.1, c: values.2)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.mixedAssociatedValues,
                  description: #"""
                  Multiple associated values with some named and some unnamed
                  """#,
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
          private enum __macro_local_7CaseKeyfMu_: Swift.CodingKey {
            case simple
            enum AssociatedValuesKey_simple: Swift.CodingKey {
            }
            case singleAssociatedValue
            enum AssociatedValuesKey_singleAssociatedValue: Swift.CodingKey {
            }
            case mutlipleUnnamedAssociatedValues
            enum AssociatedValuesKey_mutlipleUnnamedAssociatedValues: Swift.CodingKey {
            }
            case multipleNamedAssociatedValues
            enum AssociatedValuesKey_multipleNamedAssociatedValues: Swift.CodingKey {
              case a
              case b
              case c
            }
            case mixedAssociatedValues
            enum AssociatedValuesKey_mixedAssociatedValues: Swift.CodingKey {
              case b
              case c
            }
          }
        }
        """##,
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

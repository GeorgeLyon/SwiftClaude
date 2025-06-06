import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import SchemaCodingMacros

@Suite("@SchemaCodable Enum")
private struct EnumMacroTests {

  @Test
  func testEnumMacro() {

    assertMacroExpansion(
      """
      @SchemaCodable
      enum TestEnum {
        case `simple`
        /// A case with a single associated value
        case singleAssociatedValue(Int)
        /// Multiple cases in a single declaration
        case oneCase, twoCase, redCase(String), blueCase(Int)
        // Multiple associated values without a name
        case mutlipleUnnamedAssociatedValues(Int, String)
        // Multiple associated values with a name
        case multipleNamedAssociatedValues(a: Int, b: String, c: Bool)
        // Multiple associated values with some named and some unnamed
        case mixedAssociatedValues(Int, b: String, c: Bool)
      }
      """,
      expandedSource: ##"""
        enum TestEnum {
          case `simple`
          /// A case with a single associated value
          case singleAssociatedValue(Int)
          /// Multiple cases in a single declaration
          case oneCase, twoCase, redCase(String), blueCase(Int)
          // Multiple associated values without a name
          case mutlipleUnnamedAssociatedValues(Int, String)
          // Multiple associated values with a name
          case multipleNamedAssociatedValues(a: Int, b: String, c: Bool)
          // Multiple associated values with some named and some unnamed
          case mixedAssociatedValues(Int, b: String, c: Bool)
        }

        extension TestEnum: SchemaCodable {
          static var schema: some Schema<Self> {
            let associatedValuesSchema_0_0 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (

              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.`simple`.self
            )
            let associatedValuesSchema_1_0 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.singleAssociatedValue?.none,
                  schema: SchemaProvider.schema(representing: Int.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.singleAssociatedValue.self
            )
            let associatedValuesSchema_2_0 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.oneCase.self
            )
            let associatedValuesSchema_2_1 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.twoCase.self
            )
            let associatedValuesSchema_2_2 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.redCase?.none,
                  schema: SchemaProvider.schema(representing: String.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.redCase.self
            )
            let associatedValuesSchema_2_3 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.blueCase?.none,
                  schema: SchemaProvider.schema(representing: Int.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.blueCase.self
            )
            let associatedValuesSchema_3_0 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.mutlipleUnnamedAssociatedValues?.none,
                  schema: SchemaProvider.schema(representing: Int.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.mutlipleUnnamedAssociatedValues?.none,
                  schema: SchemaProvider.schema(representing: String.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.mutlipleUnnamedAssociatedValues.self
            )
            let associatedValuesSchema_4_0 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.multipleNamedAssociatedValues.a,
                  schema: SchemaProvider.schema(representing: Int.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.multipleNamedAssociatedValues.b,
                  schema: SchemaProvider.schema(representing: String.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.multipleNamedAssociatedValues.c,
                  schema: SchemaProvider.schema(representing: Bool.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.multipleNamedAssociatedValues.self
            )
            let associatedValuesSchema_5_0 = SchemaProvider.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.mixedAssociatedValues?.none,
                  schema: SchemaProvider.schema(representing: Int.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.mixedAssociatedValues.b,
                  schema: SchemaProvider.schema(representing: String.self)
                ), (
                  key: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.mixedAssociatedValues.c,
                  schema: SchemaProvider.schema(representing: Bool.self)
                )
              ),
              keyedBy: __macro_local_7CaseKeyfMu_.AssociatedValuesKey.mixedAssociatedValues.self
            )
            return SchemaProvider.enumSchema(
              representing: Self.self,
              description: nil,
              keyedBy: __macro_local_7CaseKeyfMu_.self,
              cases: (
                (
                  key: __macro_local_7CaseKeyfMu_.`simple`,
                  description: nil,
                  associatedValuesSchema: associatedValuesSchema_0_0,
                  initializer: { @Sendable values in
                    .`simple`
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.singleAssociatedValue,
                  description: #"""
                  A case with a single associated value
                  """#,
                  associatedValuesSchema: associatedValuesSchema_1_0,
                  initializer: { @Sendable values in
                    .singleAssociatedValue(values)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.oneCase,
                  description: #"""
                  Multiple cases in a single declaration
                  """#,
                  associatedValuesSchema: associatedValuesSchema_2_0,
                  initializer: { @Sendable values in
                    .oneCase
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.twoCase,
                  description: #"""
                  Multiple cases in a single declaration
                  """#,
                  associatedValuesSchema: associatedValuesSchema_2_1,
                  initializer: { @Sendable values in
                    .twoCase
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.redCase,
                  description: #"""
                  Multiple cases in a single declaration
                  """#,
                  associatedValuesSchema: associatedValuesSchema_2_2,
                  initializer: { @Sendable values in
                    .redCase(values)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.blueCase,
                  description: #"""
                  Multiple cases in a single declaration
                  """#,
                  associatedValuesSchema: associatedValuesSchema_2_3,
                  initializer: { @Sendable values in
                    .blueCase(values)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.mutlipleUnnamedAssociatedValues,
                  description: #"""
                  Multiple associated values without a name
                  """#,
                  associatedValuesSchema: associatedValuesSchema_3_0,
                  initializer: { @Sendable values in
                    .mutlipleUnnamedAssociatedValues(values.0, values.1)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.multipleNamedAssociatedValues,
                  description: #"""
                  Multiple associated values with a name
                  """#,
                  associatedValuesSchema: associatedValuesSchema_4_0,
                  initializer: { @Sendable values in
                    .multipleNamedAssociatedValues(a: values.0, b: values.1, c: values.2)
                  }
                ),
                (
                  key: __macro_local_7CaseKeyfMu_.mixedAssociatedValues,
                  description: #"""
                  Multiple associated values with some named and some unnamed
                  """#,
                  associatedValuesSchema: associatedValuesSchema_5_0,
                  initializer: { @Sendable values in
                    .mixedAssociatedValues(values.0, b: values.1, c: values.2)
                  }
                )
              ),
              caseEncoder: { @Sendable value, encoder_0, encoder_1, encoder_2, encoder_3, encoder_4, encoder_5, encoder_6, encoder_7, encoder_8 in
                switch value {
                case .`simple`:
                  encoder_0(())
                case .singleAssociatedValue(let _0):
                  encoder_1((_0))
                case .oneCase:
                  encoder_2(())
                case .twoCase:
                  encoder_3(())
                case .redCase(let _0):
                  encoder_4((_0))
                case .blueCase(let _0):
                  encoder_5((_0))
                case .mutlipleUnnamedAssociatedValues(let _0, let _1):
                  encoder_6((_0, _1))
                case .multipleNamedAssociatedValues(let a, let b, let c):
                  encoder_7((a, b, c))
                case .mixedAssociatedValues(let _0, let b, let c):
                  encoder_8((_0, b, c))
                }
              }
            )
          }
          private enum __macro_local_7CaseKeyfMu_: Swift.CodingKey {
            case `simple`
            case singleAssociatedValue
            case oneCase
            case twoCase
            case redCase
            case blueCase
            case mutlipleUnnamedAssociatedValues
            case multipleNamedAssociatedValues
            case mixedAssociatedValues
            enum AssociatedValuesKey {
              enum `simple`: Swift.CodingKey {
              }
              enum singleAssociatedValue: Swift.CodingKey {
              }
              enum oneCase: Swift.CodingKey {
              }
              enum twoCase: Swift.CodingKey {
              }
              enum redCase: Swift.CodingKey {
              }
              enum blueCase: Swift.CodingKey {
              }
              enum mutlipleUnnamedAssociatedValues: Swift.CodingKey {
              }
              enum multipleNamedAssociatedValues: Swift.CodingKey {
                case a
                case b
                case c
              }
              enum mixedAssociatedValues: Swift.CodingKey {
                case b
                case c
              }
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
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self)
  ]
}

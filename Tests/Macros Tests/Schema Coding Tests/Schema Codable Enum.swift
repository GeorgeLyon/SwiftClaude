import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

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
      expandedSource: #####"""
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

        extension TestEnum: SchemaCoding.SchemaCodable {
          static var schema: some SchemaCoding.Schema<Self> {
            let associatedValuesSchema_0_0 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (

              )
            )
            let associatedValuesSchema_1_0 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Int.self)
                )
              )
            )
            let associatedValuesSchema_2_0 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (

              )
            )
            let associatedValuesSchema_2_1 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (

              )
            )
            let associatedValuesSchema_2_2 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaCoding.SchemaSupport.schema(representing: String.self)
                )
              )
            )
            let associatedValuesSchema_2_3 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Int.self)
                )
              )
            )
            let associatedValuesSchema_3_0 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Int.self)
                ), (
                  key: nil,
                  schema: SchemaCoding.SchemaSupport.schema(representing: String.self)
                )
              )
            )
            let associatedValuesSchema_4_0 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: "a" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Int.self)
                ), (
                  key: "b" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: String.self)
                ), (
                  key: "c" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Bool.self)
                )
              )
            )
            let associatedValuesSchema_5_0 = SchemaCoding.SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Int.self)
                ), (
                  key: "b" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: String.self)
                ), (
                  key: "c" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Bool.self)
                )
              )
            )
            return SchemaCoding.SchemaSupport.enumSchema(
              representing: Self.self,
              description: nil,
              cases: (
                (
                  key: "simple" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: nil,
                  schema: associatedValuesSchema_0_0,
                  initializer: { @Sendable values in
                    .`simple`
                  }
                ),
                (
                  key: "singleAssociatedValue" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A case with a single associated value
                  """####,
                  schema: associatedValuesSchema_1_0,
                  initializer: { @Sendable values in
                    .singleAssociatedValue(values)
                  }
                ),
                (
                  key: "oneCase" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  Multiple cases in a single declaration
                  """####,
                  schema: associatedValuesSchema_2_0,
                  initializer: { @Sendable values in
                    .oneCase
                  }
                ),
                (
                  key: "twoCase" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  Multiple cases in a single declaration
                  """####,
                  schema: associatedValuesSchema_2_1,
                  initializer: { @Sendable values in
                    .twoCase
                  }
                ),
                (
                  key: "redCase" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  Multiple cases in a single declaration
                  """####,
                  schema: associatedValuesSchema_2_2,
                  initializer: { @Sendable values in
                    .redCase(values)
                  }
                ),
                (
                  key: "blueCase" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  Multiple cases in a single declaration
                  """####,
                  schema: associatedValuesSchema_2_3,
                  initializer: { @Sendable values in
                    .blueCase(values)
                  }
                ),
                (
                  key: "mutlipleUnnamedAssociatedValues" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  Multiple associated values without a name
                  """####,
                  schema: associatedValuesSchema_3_0,
                  initializer: { @Sendable values in
                    .mutlipleUnnamedAssociatedValues(values.0, values.1)
                  }
                ),
                (
                  key: "multipleNamedAssociatedValues" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  Multiple associated values with a name
                  """####,
                  schema: associatedValuesSchema_4_0,
                  initializer: { @Sendable values in
                    .multipleNamedAssociatedValues(a: values.0, b: values.1, c: values.2)
                  }
                ),
                (
                  key: "mixedAssociatedValues" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  Multiple associated values with some named and some unnamed
                  """####,
                  schema: associatedValuesSchema_5_0,
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
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self)
  ]
}

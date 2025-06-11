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
      @ToolInput
      enum ToolInputEnum {
        case `simple`
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
      expandedSource: #####"""
        enum ToolInputEnum {
          case `simple`
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
          static var schema: some ToolInput.Schema<Self> {
            let associatedValuesSchema_0_0 = ToolInput.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
              values: (

              )
            )
            let associatedValuesSchema_1_0 = ToolInput.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)
                )
              )
            )
            let associatedValuesSchema_2_0 = ToolInput.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)
                ), (
                  key: nil,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)
                )
              )
            )
            let associatedValuesSchema_3_0 = ToolInput.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: "a" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)
                ), (
                  key: "b" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)
                ), (
                  key: "c" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Bool.self)
                )
              )
            )
            let associatedValuesSchema_4_0 = ToolInput.SchemaCodingSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)
                ), (
                  key: "b" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)
                ), (
                  key: "c" as ToolInput.SchemaCodingKey,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Bool.self)
                )
              )
            )
            return ToolInput.SchemaCodingSupport.enumSchema(
              representing: Self.self,
              description: nil,
              cases: (
                (
                  key: "simple" as ToolInput.SchemaCodingKey,
                  description: nil,
                  schema: associatedValuesSchema_0_0,
                  initializer: { @Sendable values in
                    .`simple`
                  }
                ),
                (
                  key: "singleAssociatedValue" as ToolInput.SchemaCodingKey,
                  description: ####"""
                  A case with a single associated value
                  """####,
                  schema: associatedValuesSchema_1_0,
                  initializer: { @Sendable values in
                    .singleAssociatedValue(values)
                  }
                ),
                (
                  key: "mutlipleUnnamedAssociatedValues" as ToolInput.SchemaCodingKey,
                  description: ####"""
                  Multiple associated values without a name
                  """####,
                  schema: associatedValuesSchema_2_0,
                  initializer: { @Sendable values in
                    .mutlipleUnnamedAssociatedValues(values.0, values.1)
                  }
                ),
                (
                  key: "multipleNamedAssociatedValues" as ToolInput.SchemaCodingKey,
                  description: ####"""
                  Multiple associated values with a name
                  """####,
                  schema: associatedValuesSchema_3_0,
                  initializer: { @Sendable values in
                    .multipleNamedAssociatedValues(a: values.0, b: values.1, c: values.2)
                  }
                ),
                (
                  key: "mixedAssociatedValues" as ToolInput.SchemaCodingKey,
                  description: ####"""
                  Multiple associated values with some named and some unnamed
                  """####,
                  schema: associatedValuesSchema_4_0,
                  initializer: { @Sendable values in
                    .mixedAssociatedValues(values.0, b: values.1, c: values.2)
                  }
                )
              ),
              caseEncoder: { @Sendable value, encoder_0, encoder_1, encoder_2, encoder_3, encoder_4 in
                switch value {
                case .`simple`:
                  encoder_0(())
                case .singleAssociatedValue(let _0):
                  encoder_1((_0))
                case .mutlipleUnnamedAssociatedValues(let _0, let _1):
                  encoder_2((_0, _1))
                case .multipleNamedAssociatedValues(let a, let b, let c):
                  encoder_3((a, b, c))
                case .mixedAssociatedValues(let _0, let b, let c):
                  encoder_4((_0, b, c))
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
    "ToolInput": MacroSpec(type: ToolInputMacro.self)
  ]
}

import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import ToolMacros

@Suite("@ToolInput Enum")
private struct EnumMacroTests {

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
      expandedSource: ##"""
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
          static var schema: some Schema<Self> {
            let associatedValuesSchema_0_0 = SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (

              )
            )
            let associatedValuesSchema_1_0 = SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaSupport.schema(representing: Int.self)
                )
              )
            )
            let associatedValuesSchema_2_0 = SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaSupport.schema(representing: Int.self)
                ), (
                  key: nil,
                  schema: SchemaSupport.schema(representing: String.self)
                )
              )
            )
            let associatedValuesSchema_3_0 = SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: "a" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: Int.self)
                ), (
                  key: "b" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: String.self)
                ), (
                  key: "c" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: Bool.self)
                )
              )
            )
            let associatedValuesSchema_4_0 = SchemaSupport.enumCaseAssociatedValuesSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaSupport.schema(representing: Int.self)
                ), (
                  key: "b" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: String.self)
                ), (
                  key: "c" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: Bool.self)
                )
              )
            )
            return SchemaSupport.enumSchema(
              representing: Self.self,
              description: nil,
              cases: (
                (
                  key: "simple" as SchemaSupport.SchemaCodingKey,
                  description: nil,
                  associatedValuesSchema: associatedValuesSchema_0_0,
                  initializer: { @Sendable values in
                    .`simple`
                  }
                ),
                (
                  key: "singleAssociatedValue" as SchemaSupport.SchemaCodingKey,
                  description: #"""
                  A case with a single associated value
                  """#,
                  associatedValuesSchema: associatedValuesSchema_1_0,
                  initializer: { @Sendable values in
                    .singleAssociatedValue(values)
                  }
                ),
                (
                  key: "mutlipleUnnamedAssociatedValues" as SchemaSupport.SchemaCodingKey,
                  description: #"""
                  Multiple associated values without a name
                  """#,
                  associatedValuesSchema: associatedValuesSchema_2_0,
                  initializer: { @Sendable values in
                    .mutlipleUnnamedAssociatedValues(values.0, values.1)
                  }
                ),
                (
                  key: "multipleNamedAssociatedValues" as SchemaSupport.SchemaCodingKey,
                  description: #"""
                  Multiple associated values with a name
                  """#,
                  associatedValuesSchema: associatedValuesSchema_3_0,
                  initializer: { @Sendable values in
                    .multipleNamedAssociatedValues(a: values.0, b: values.1, c: values.2)
                  }
                ),
                (
                  key: "mixedAssociatedValues" as SchemaSupport.SchemaCodingKey,
                  description: #"""
                  Multiple associated values with some named and some unnamed
                  """#,
                  associatedValuesSchema: associatedValuesSchema_4_0,
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

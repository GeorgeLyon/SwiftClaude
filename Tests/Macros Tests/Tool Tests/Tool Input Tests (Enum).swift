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

        @ToolInputDetails(
          description: "A case with a single associated value"
        )
        case singleAssociatedValue(Int)

        @ToolInputDetails(
          description: "Multiple associated values without a name"
        )
        case mutlipleUnnamedAssociatedValues(Int, String)

        @ToolInputDetails(
          description: "Multiple associated values with a name"
        )
        case multipleNamedAssociatedValues(a: Int, b: String, c: Bool)

        @ToolInputDetails(
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
          static var schema: some ToolInput.Schema<Self> {
            let `simple` = ToolInput.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.`simple`,
              associatedValues: {
              },
              initializer: { value in
                Self.`simple`
              })
            let singleAssociatedValue = ToolInput.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.singleAssociatedValue,
              description: "A case with a single associated value",
              associatedValues: {
                ToolInput.SchemaCodingSupport.EnumSchemaCaseUnlabeledAssociatedValue(
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)

                )
              },
              initializer: { value in
                Self.singleAssociatedValue(value)
              })
            let mutlipleUnnamedAssociatedValues = ToolInput.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.mutlipleUnnamedAssociatedValues,
              description: "Multiple associated values without a name",
              associatedValues: {
                ToolInput.SchemaCodingSupport.EnumSchemaCaseUnlabeledAssociatedValue(
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)

                )
                ToolInput.SchemaCodingSupport.EnumSchemaCaseUnlabeledAssociatedValue(
                  schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)

                )
              },
              initializer: { value in
                Self.mutlipleUnnamedAssociatedValues(value.0, value.1)
              })
            let multipleNamedAssociatedValues = ToolInput.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.multipleNamedAssociatedValues,
              description: "Multiple associated values with a name",
              associatedValues: {
                ToolInput.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_29multipleNamedAssociatedValuesfMu_.a,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)

                )
                ToolInput.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_29multipleNamedAssociatedValuesfMu_.b,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)

                )
                ToolInput.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_29multipleNamedAssociatedValuesfMu_.c,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Bool.self)

                )
              },
              initializer: { value in
                Self.multipleNamedAssociatedValues(a: value.0, b: value.1, c: value.2)
              })
            let mixedAssociatedValues = ToolInput.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.mixedAssociatedValues,
              description: "Multiple associated values with some named and some unnamed",
              associatedValues: {
                ToolInput.SchemaCodingSupport.EnumSchemaCaseUnlabeledAssociatedValue(
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Int.self)

                )
                ToolInput.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_21mixedAssociatedValuesfMu_.b,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: String.self)

                )
                ToolInput.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_21mixedAssociatedValuesfMu_.c,
                  schema: ToolInput.SchemaCodingSupport.schema(representing: Bool.self)

                )
              },
              initializer: { value in
                Self.mixedAssociatedValues(value.0, b: value.1, c: value.2)
              })
            return ToolInput.SchemaCodingSupport.enumSchema(
              representing: Self.self,
              description: "A Tool Input Enum",
              cases: ToolInput.SchemaCodingSupport.EnumSchemaCases {
                `simple`
                singleAssociatedValue
                mutlipleUnnamedAssociatedValues
                multipleNamedAssociatedValues
                mixedAssociatedValues
              },
              valueEncoder: { value, encoder in
                switch value {
                case .`simple`:
                  let encoding = encoder.encodings.0
                  encoder.encode((), using: encoding)
                case .singleAssociatedValue(let _0):
                  let encoding = encoder.encodings.1
                  encoder.encode((_0), using: encoding)
                case .mutlipleUnnamedAssociatedValues(let _0, let _1):
                  let encoding = encoder.encodings.2
                  encoder.encode((_0, _1), using: encoding)
                case .multipleNamedAssociatedValues(let a, let b, let c):
                  let encoding = encoder.encodings.3
                  encoder.encode((a, b, c), using: encoding)
                case .mixedAssociatedValues(let _0, let b, let c):
                  let encoding = encoder.encodings.4
                  encoder.encode((_0, b, c), using: encoding)
                }
              })
          }
          private enum __macro_local_9CodingKeyfMu_: Swift.String, Swift.CodingKey {
            case `simple` = "simple"
            case singleAssociatedValue = "singleAssociatedValue"
            case mutlipleUnnamedAssociatedValues = "mutlipleUnnamedAssociatedValues"
            case multipleNamedAssociatedValues = "multipleNamedAssociatedValues"
            case mixedAssociatedValues = "mixedAssociatedValues"
          }
          private enum __macro_local_21singleAssociatedValuefMu_: Swift.CodingKey {
          }
          private enum __macro_local_31mutlipleUnnamedAssociatedValuesfMu_: Swift.CodingKey {
          }
          private enum __macro_local_29multipleNamedAssociatedValuesfMu_: Swift.String, Swift.CodingKey {
            case a = "a"
            case b = "b"
            case c = "c"
          }
          private enum __macro_local_21mixedAssociatedValuesfMu_: Swift.String, Swift.CodingKey {
            case b = "b"
            case c = "c"
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
    "ToolInputDetails": MacroSpec(type: SchemaDetailsMacro.self),
  ]
}

import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@SchemaCodable Enum")
struct SchemaCodableEnumMacroTests {

  @Test
  func testEnumMacro() {
    assertMacroExpansion(
      """
      @SchemaCodable(
        description: "The Foo enum"
      )
      enum Foo {

        @SchemaDetails(
          description: "Description of Bar"
        )
        case bar
      }
      """,
      expandedSource: #####"""
        enum Foo {
          case bar
        }

        extension Foo: SchemaCoding.SchemaCodable {
          static var schema: some SchemaCoding.Schema<Self> {
            let bar = SchemaCoding.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.bar,
              description: "Description of Bar",
              associatedValues: {
              },
              initializer: { value in
                Self.bar
              })
            return SchemaCoding.SchemaCodingSupport.enumSchema(
              representing: Self.self,
              description: "The Foo enum",
              cases: SchemaCoding.SchemaCodingSupport.EnumSchemaCases {
                bar
              },
              valueEncoder: { value, encoder in
                switch value {
                case .bar:
                  let encoding = encoder.encodings.0
                  encoder.encode((), using: encoding)
                }
              })
          }
          private enum __macro_local_9CodingKeyfMu_: Swift.String, Swift.CodingKey {
            case bar = "bar"
          }
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  @Test
  func testSingleCaseEnumMacro() {
    assertMacroExpansion(
      """
      @SchemaCodable
      enum SingleCaseEnum: Equatable {
        /**
         The only case
         */
        case only(String)
      }
      """,
      expandedSource: #####"""
        enum SingleCaseEnum: Equatable {
          /**
           The only case
           */
          case only(String)
        }

        extension SingleCaseEnum: SchemaCoding.SchemaCodable {
          static var schema: some SchemaCoding.Schema<Self> {
            let only = SchemaCoding.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.only,
              associatedValues: {
                SchemaCoding.SchemaCodingSupport.EnumSchemaCaseUnlabeledAssociatedValue(
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: String.self)

                )
              },
              initializer: { value in
                Self.only(value)
              })
            return SchemaCoding.SchemaCodingSupport.enumSchema(
              representing: Self.self,
              cases: SchemaCoding.SchemaCodingSupport.EnumSchemaCases {
                only
              },
              valueEncoder: { value, encoder in
                switch value {
                case .only(let _0):
                  let encoding = encoder.encodings.0
                  encoder.encode((_0), using: encoding)
                }
              })
          }
          private enum __macro_local_9CodingKeyfMu_: Swift.String, Swift.CodingKey {
            case only = "only"
          }
          private enum __macro_local_4onlyfMu_: Swift.CodingKey {
          }
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  private let macroSpecs = [
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self),
    "SchemaDetails": MacroSpec(type: SchemaDetailsMacro.self),
  ]
}

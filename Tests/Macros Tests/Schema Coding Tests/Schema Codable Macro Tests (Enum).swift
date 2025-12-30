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

        @SchemaCase(
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
          static var schema: some SchemaCoding.Schema<Self> & SchemaCoding.Support.ComplexSchema {
            SchemaCoding.Support.enumSchema(
              description: "The Foo enum",
              cases: {
                SchemaCoding.Support.enumSchemaCase(
                  name: "bar",
                  description: "Description of Bar",
                  associatedValues: {
                  },
                  finishDecoding: { (decoder: SchemaCoding.EnumCaseDecoder< >) in
                    Self.bar
                  }
                )
              },
              encodeValue: { value, encoder in
                switch value {
                case .bar:
                  encoder.encode((), using: encoder.encodings.0)
                }
              }
            )
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
          static var schema: some SchemaCoding.Schema<Self> & SchemaCoding.Support.ComplexSchema {
            SchemaCoding.Support.enumSchema(
              cases: {
                SchemaCoding.Support.enumSchemaCase(
                  name: "only",
                  associatedValues: {
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      schema: SchemaCoding.Support.schema(
                        representing: String.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<String>) in
                    Self.only(
                      decoder.associatedValues.0
                    )
                  }
                )
              },
              encodeValue: { value, encoder in
                switch value {
                case .only(let __value_0):
                  encoder.encode((__value_0), using: encoder.encodings.0)
                }
              }
            )
          }
        }
        """#####,
      macroSpecs: macroSpecs
    )
  }

  private let macroSpecs = [
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self),
    "SchemaCase": MacroSpec(type: SchemaCaseMacro.self),
  ]
}

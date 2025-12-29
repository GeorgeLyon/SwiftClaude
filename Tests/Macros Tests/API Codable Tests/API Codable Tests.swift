import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@APICodable")
struct APICodableMacroTests {

  @Test
  func testEnumMacro() {
    assertMacroExpansion(
      """
      @APICodable
      enum Foo {

        struct Bar {
        }
        case bar(Bar)
      }
      """,
      expandedSource: #####"""
        enum Foo {

          struct Bar {
          }
          case bar(Bar)
        }

        extension Foo: APICodable.SchemaCodable {
          static var schema: some APICodable.Schema<Self> & APICodable.Support.ComplexSchema {
            APICodable.Support.enumSchema(
              style: .internallyTagged(
                discriminatorPropertyName: "type"
              ),
              cases: {
                APICodable.Support.enumSchemaCase(
                  name: "bar",
                  associatedValues: {
                    APICodable.Support.enumSchemaCaseAssociatedValue(
                      schema: APICodable.Support.schema(
                        representing: Bar.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: APICodable.EnumSingleAssociatedValueCaseDecoder<Bar>) in
                    Self.bar(
                      decoder.associatedValues.0
                    )
                  }
                )
              },
              encodeValue: { value, encoder in
                switch value {
                case .bar(let __value_0):
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
    "APICodable": MacroSpec(type: APICodableMacro.self)
  ]
}

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
          static var schema: some APICodable.Schema<Self> {
            let bar = APICodable.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.bar,
              associatedValues: {
                APICodable.SchemaCodingSupport.EnumSchemaCaseUnlabeledAssociatedValue(
                  schema: APICodable.SchemaCodingSupport.schema(representing: Bar.self)

                )
              },
              initializer: { value in
                Self.bar(value)
              })
            return APICodable.SchemaCodingSupport.enumSchema(
              representing: Self.self,
              style: .internallyTagged(
                discriminatorPropertyName: "type"
              ),
              cases: APICodable.SchemaCodingSupport.EnumSchemaCases {
                bar
              },
              valueEncoder: { value, encoder in
                switch value {
                case .bar(let _0):
                  let encoding = encoder.encodings.0
                  encoder.encode((_0), using: encoding)
                }
              })
          }
          private enum __macro_local_9CodingKeyfMu_: Swift.String, Swift.CodingKey {
            case bar = "bar"
          }
          private enum __macro_local_3barfMu_: Swift.CodingKey {
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

import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@SchemaCodable Internally Tagged Enum")
struct InternallyTaggedEnumMacroTests {

  @Test
  func testInternallyTaggedEnumMacro() {

    assertMacroExpansion(
      """
      @SchemaCodable(
        style: .internallyTagged(
          discriminatorPropertyName: "type"
        )
      )
      enum Shape {
        @SchemaParameters(
          description: "A circle with a radius"
        )
        case circle(radius: Double)
        @SchemaParameters(
          description: "A rectangle with width and height"
        )
        case rectangle(width: Double, height: Double)
        @SchemaParameters(
          description: "A square with a side length"
        )
        case square(side: Double)
      }
      """,
      expandedSource: #####"""
        enum Shape {
          case circle(radius: Double)
          case rectangle(width: Double, height: Double)
          case square(side: Double)
        }

        extension Shape: SchemaCoding.SchemaCodable {
          static var schema: some SchemaCoding.Schema<Self> {
            SchemaCoding.Support.enumSchema(
              style: .internallyTagged(
                discriminatorPropertyName: "type"
              ),
              cases: {
                SchemaCoding.Support.enumSchemaCase(
                  name: "circle".circle,
                  description: "A circle with a radius",
                  associatedValues: {
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: __macro_local_26AssociatedValueLabe_circlefMu_.radius,
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                  },
                  finishDecoding: { (__value_0) in
                    Self.circle(
                      radius: __value_0
                    )
                  }
                )
                SchemaCoding.Support.enumSchemaCase(
                  name: "rectangle".rectangle,
                  description: "A rectangle with width and height",
                  associatedValues: {
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: __macro_local_29AssociatedValueLabe_rectanglefMu_.width,
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: __macro_local_29AssociatedValueLabe_rectanglefMu_.height,
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                  },
                  finishDecoding: { (__value_0, __value_1) in
                    Self.rectangle(
                      width: __value_0, height: __value_1
                    )
                  }
                )
                SchemaCoding.Support.enumSchemaCase(
                  name: "square".square,
                  description: "A square with a side length",
                  associatedValues: {
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: __macro_local_26AssociatedValueLabe_squarefMu_.side,
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                  },
                  finishDecoding: { (__value_0) in
                    Self.square(
                      side: __value_0
                    )
                  }
                )
              },
              encodeValue: { value, encoder in
                let encodings = encoder.encodings
                switch value {
                case .circle(let __value_0):
                  let encoding = encodings.0
                  encoder.encode((__value_0), using: encoding)
                case .rectangle(let __value_0, let __value_1):
                  let encoding = encodings.1
                  encoder.encode((__value_0, __value_1), using: encoding)
                case .square(let __value_0):
                  let encoding = encodings.2
                  encoder.encode((__value_0), using: encoding)
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
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self),
    "SchemaParameters": MacroSpec(type: SchemaParametersMacro.self),
  ]
}

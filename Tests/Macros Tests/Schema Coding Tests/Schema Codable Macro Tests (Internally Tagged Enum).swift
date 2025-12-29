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
          static var schema: some SchemaCoding.Schema<Self> & SchemaCoding.Support.ComplexSchema {
            SchemaCoding.Support.enumSchema(
              style: .internallyTagged(
                discriminatorPropertyName: "type"
              ),
              cases: {
                SchemaCoding.Support.enumSchemaCase(
                  name: "circle",
                  description: "A circle with a radius",
                  associatedValues: {
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: "radius",
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<Double>) in
                    Self.circle(
                      radius: decoder.associatedValues.0
                    )
                  }
                )
                SchemaCoding.Support.enumSchemaCase(
                  name: "rectangle",
                  description: "A rectangle with width and height",
                  associatedValues: {
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: "width",
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: "height",
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: SchemaCoding.EnumCaseDecoder<Double, Double>) in
                    Self.rectangle(
                      width: decoder.associatedValues.0, height: decoder.associatedValues.1
                    )
                  }
                )
                SchemaCoding.Support.enumSchemaCase(
                  name: "square",
                  description: "A square with a side length",
                  associatedValues: {
                    SchemaCoding.Support.enumSchemaCaseAssociatedValue(
                      label: "side",
                      schema: SchemaCoding.Support.schema(
                        representing: Double.self
                      )
                    )
                  },
                  finishDecoding: { (decoder: SchemaCoding.EnumSingleAssociatedValueCaseDecoder<Double>) in
                    Self.square(
                      side: decoder.associatedValues.0
                    )
                  }
                )
              },
              encodeValue: { value, encoder in
                switch value {
                case .circle(let __value_0):
                  encoder.encode((__value_0), using: encoder.encodings.0)
                case .rectangle(let __value_0, let __value_1):
                  encoder.encode((__value_0, __value_1), using: encoder.encodings.1)
                case .square(let __value_0):
                  encoder.encode((__value_0), using: encoder.encodings.2)
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

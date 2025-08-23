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
        @SchemaDetails(
          description: "A circle with a radius"
        )
        case circle(radius: Double)
        @SchemaDetails(
          description: "A rectangle with width and height"
        )
        case rectangle(width: Double, height: Double)
        @SchemaDetails(
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
            let circle = SchemaCoding.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.circle,
              description: "A circle with a radius",
              associatedValues: {
                SchemaCoding.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_6circlefMu_.radius,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: Double.self)

                )
              },
              initializer: { value in
                Self.circle(radius: value)
              })
            let rectangle = SchemaCoding.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.rectangle,
              description: "A rectangle with width and height",
              associatedValues: {
                SchemaCoding.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_9rectanglefMu_.width,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: Double.self)

                )
                SchemaCoding.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_9rectanglefMu_.height,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: Double.self)

                )
              },
              initializer: { value in
                Self.rectangle(width: value.0, height: value.1)
              })
            let square = SchemaCoding.SchemaCodingSupport.EnumSchemaCaseDefinition(
              name: __macro_local_9CodingKeyfMu_.square,
              description: "A square with a side length",
              associatedValues: {
                SchemaCoding.SchemaCodingSupport.EnumSchemaCaseLabeledAssociatedValue(
                  label: __macro_local_6squarefMu_.side,
                  schema: SchemaCoding.SchemaCodingSupport.schema(representing: Double.self)

                )
              },
              initializer: { value in
                Self.square(side: value)
              })
            return SchemaCoding.SchemaCodingSupport.enumSchema(
              representing: Self.self,
              style: .internallyTagged(
                discriminatorPropertyName: "type"
              ),
              cases: SchemaCoding.SchemaCodingSupport.EnumSchemaCases {
                circle
                rectangle
                square
              },
              valueEncoder: { value, encoder in
                switch value {
                case .circle(let radius):
                  let encoding = encoder.encodings.0
                  encoder.encode((radius), using: encoding)
                case .rectangle(let width, let height):
                  let encoding = encoder.encodings.1
                  encoder.encode((width, height), using: encoding)
                case .square(let side):
                  let encoding = encoder.encodings.2
                  encoder.encode((side), using: encoding)
                }
              })
          }
          private enum __macro_local_9CodingKeyfMu_: Swift.String, Swift.CodingKey {
            case circle = "circle"
            case rectangle = "rectangle"
            case square = "square"
          }
          private enum __macro_local_6circlefMu_: Swift.String, Swift.CodingKey {
            case radius = "radius"
          }
          private enum __macro_local_9rectanglefMu_: Swift.String, Swift.CodingKey {
            case width = "width"
            case height = "height"
          }
          private enum __macro_local_6squarefMu_: Swift.String, Swift.CodingKey {
            case side = "side"
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
    "SchemaDetails": MacroSpec(type: SchemaDetailsMacro.self),
  ]
}

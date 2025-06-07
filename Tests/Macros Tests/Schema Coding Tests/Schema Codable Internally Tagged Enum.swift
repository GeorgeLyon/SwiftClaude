import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import Macros

@Suite("@SchemaCodable Internally Tagged Enum")
private struct InternallyTaggedEnumMacroTests {

  @Test
  func testInternallyTaggedEnumMacro() {

    assertMacroExpansion(
      """
      @SchemaCodable(discriminatorPropertyName: "type")
      enum Shape {
        /// A circle with a radius
        case circle(radius: Double)
        /// A rectangle with width and height
        case rectangle(width: Double, height: Double)
        /// A square with a side length
        case square(side: Double)
      }
      """,
      expandedSource: #####"""
        enum Shape {
          /// A circle with a radius
          case circle(radius: Double)
          /// A rectangle with width and height
          case rectangle(width: Double, height: Double)
          /// A square with a side length
          case square(side: Double)
        }

        extension Shape: SchemaCoding.SchemaCodable {
          static var schema: some SchemaCoding.Schema<Self> {
            let associatedValuesSchema_0_0 = SchemaCoding.SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: "radius" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Double.self)
                )
              )
            )
            let associatedValuesSchema_1_0 = SchemaCoding.SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: "width" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Double.self)
                ), (
                  key: "height" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Double.self)
                )
              )
            )
            let associatedValuesSchema_2_0 = SchemaCoding.SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: "side" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  schema: SchemaCoding.SchemaSupport.schema(representing: Double.self)
                )
              )
            )
            return SchemaCoding.SchemaSupport.internallyTaggedEnumSchema(
              representing: Self.self,
              description: nil,
              discriminatorPropertyName: "type",
              cases: (
                (
                  key: "circle" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A circle with a radius
                  """####,
                  schema: associatedValuesSchema_0_0,
                  initializer: { @Sendable values in
                    .circle(radius: values.0)
                  }
                ),
                (
                  key: "rectangle" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A rectangle with width and height
                  """####,
                  schema: associatedValuesSchema_1_0,
                  initializer: { @Sendable values in
                    .rectangle(width: values.0, height: values.1)
                  }
                ),
                (
                  key: "square" as SchemaCoding.SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A square with a side length
                  """####,
                  schema: associatedValuesSchema_2_0,
                  initializer: { @Sendable values in
                    .square(side: values.0)
                  }
                )
              ),
              caseEncoder: { @Sendable value, encoder_0, encoder_1, encoder_2 in
                switch value {
                case .circle(let radius):
                  encoder_0((radius,))
                case .rectangle(let width, let height):
                  encoder_1((width, height))
                case .square(let side):
                  encoder_2((side,))
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

  @Test
  func testInternallyTaggedEnumWithMixedCases() {

    assertMacroExpansion(
      """
      @SchemaCodable(discriminatorPropertyName: "animal")
      enum Animal {
        /// A dog with a name and favorite toy
        case dog(name: String, favoriteToy: String)
        /// A cat with a name and number of lives
        case cat(name: String, lives: Int)
        /// A bird that can fly
        case bird(canFly: Bool)
        /// A fish with no properties
        case fish
      }
      """,
      expandedSource: #####"""
        enum Animal {
          /// A dog with a name and favorite toy
          case dog(name: String, favoriteToy: String)
          /// A cat with a name and number of lives
          case cat(name: String, lives: Int)
          /// A bird that can fly
          case bird(canFly: Bool)
          /// A fish with no properties
          case fish
        }

        extension Animal: SchemaSupport.SchemaCodable {
          static var schema: some SchemaSupport.Schema<Self> {
            let associatedValuesSchema_0_0 = SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: "name" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: String.self)
                ), (
                  key: "favoriteToy" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: String.self)
                )
              )
            )
            let associatedValuesSchema_1_0 = SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: "name" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: String.self)
                ), (
                  key: "lives" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: Int.self)
                )
              )
            )
            let associatedValuesSchema_2_0 = SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: "canFly" as SchemaSupport.SchemaCodingKey,
                  schema: SchemaSupport.schema(representing: Bool.self)
                ),
              )
            )
            let associatedValuesSchema_3_0 = SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (

              )
            )
            return SchemaSupport.internallyTaggedEnumSchema(
              representing: Self.self,
              description: nil,
              discriminatorPropertyName: "animal",
              cases: (
                (
                  key: "dog" as SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A dog with a name and favorite toy
                  """####,
                  schema: associatedValuesSchema_0_0,
                  initializer: { @Sendable values in
                    .dog(name: values.0, favoriteToy: values.1)
                  }
                ),
                (
                  key: "cat" as SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A cat with a name and number of lives
                  """####,
                  schema: associatedValuesSchema_1_0,
                  initializer: { @Sendable values in
                    .cat(name: values.0, lives: values.1)
                  }
                ),
                (
                  key: "bird" as SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A bird that can fly
                  """####,
                  schema: associatedValuesSchema_2_0,
                  initializer: { @Sendable values in
                    .bird(canFly: values.0)
                  }
                ),
                (
                  key: "fish" as SchemaSupport.SchemaCodingKey,
                  description: ####"""
                  A fish with no properties
                  """####,
                  schema: associatedValuesSchema_3_0,
                  initializer: { @Sendable values in
                    .fish
                  }
                )
              ),
              caseEncoder: { @Sendable value, encoder_0, encoder_1, encoder_2, encoder_3 in
                switch value {
                case .dog(let name, let favoriteToy):
                  encoder_0((name, favoriteToy))
                case .cat(let name, let lives):
                  encoder_1((name, lives))
                case .bird(let canFly):
                  encoder_2((canFly,))
                case .fish:
                  encoder_3(())
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

  @Test
  func testInternallyTaggedEnumWithUnnamedAssociatedValues() {

    assertMacroExpansion(
      """
      @SchemaCodable(discriminatorPropertyName: "type")
      enum Request {
        case get(String)
        case post(String, Data)
        case delete(String, Bool)
      }
      """,
      expandedSource: #####"""
        enum Request {
          case get(String)
          case post(String, Data)
          case delete(String, Bool)
        }

        extension Request: SchemaSupport.SchemaCodable {
          static var schema: some SchemaSupport.Schema<Self> {
            let associatedValuesSchema_0_0 = SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaSupport.schema(representing: String.self)
                ),
              )
            )
            let associatedValuesSchema_1_0 = SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaSupport.schema(representing: String.self)
                ), (
                  key: nil,
                  schema: SchemaSupport.schema(representing: Data.self)
                )
              )
            )
            let associatedValuesSchema_2_0 = SchemaSupport.internallyTaggedEnumCaseSchema(
              values: (
                (
                  key: nil,
                  schema: SchemaSupport.schema(representing: String.self)
                ), (
                  key: nil,
                  schema: SchemaSupport.schema(representing: Bool.self)
                )
              )
            )
            return SchemaSupport.internallyTaggedEnumSchema(
              representing: Self.self,
              description: nil,
              discriminatorPropertyName: "type",
              cases: (
                (
                  key: "get" as SchemaSupport.SchemaCodingKey,
                  description: nil,
                  schema: associatedValuesSchema_0_0,
                  initializer: { @Sendable values in
                    .get(values)
                  }
                ),
                (
                  key: "post" as SchemaSupport.SchemaCodingKey,
                  description: nil,
                  schema: associatedValuesSchema_1_0,
                  initializer: { @Sendable values in
                    .post(values.0, values.1)
                  }
                ),
                (
                  key: "delete" as SchemaSupport.SchemaCodingKey,
                  description: nil,
                  schema: associatedValuesSchema_2_0,
                  initializer: { @Sendable values in
                    .delete(values.0, values.1)
                  }
                )
              ),
              caseEncoder: { @Sendable value, encoder_0, encoder_1, encoder_2 in
                switch value {
                case .get(let _0):
                  encoder_0((_0))
                case .post(let _0, let _1):
                  encoder_1((_0, _1))
                case .delete(let _0, let _1):
                  encoder_2((_0, _1))
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
    "SchemaCodable": MacroSpec(type: InternallyTaggedEnumSchemaCodableMacro.self)
  ]
}

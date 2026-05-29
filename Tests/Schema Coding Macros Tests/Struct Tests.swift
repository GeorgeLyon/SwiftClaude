import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import SchemaCodingMacros

@Suite
struct SchemaCodableStructTests {

  private let macroSpecs: [String: MacroSpec] = [
    "SchemaCodable": MacroSpec(type: SchemaCodableMacro.self),
    "SchemaProperty": MacroSpec(type: SchemaPropertyMacro.self),
  ]

  @Test
  func structWithTwoProperties() {
    assertMacroExpansion(
      """
      @SchemaCodable
      struct Point {
        let x: Int
        let y: Int
      }
      """,
      expandedSource: #"""
        struct Point {
          let x: Int
          let y: Int
        }

        extension Point: SchemaCoding.SchemaCodable {
          static var schema: Schema {
            Schema()
          }
          struct Schema: SchemaCoding.Support.ObjectSchema {
            typealias Value = Point
            typealias __macro_local_1xfMu_ = Int.Schema.ObjectProperty
            typealias __macro_local_1yfMu_ = Int.Schema.ObjectProperty
            typealias ObjectPropertyTypeMetadatas = (SchemaCoding.Support.ObjectPropertyTypeMetadata<Value, __macro_local_1xfMu_>, SchemaCoding.Support.ObjectPropertyTypeMetadata<Value, __macro_local_1yfMu_>)
            static func propertyTypeMetadatas() -> ObjectPropertyTypeMetadatas {
              (SchemaCoding.Support.ObjectPropertyTypeMetadata(
                  name: "x",
                  keyPath: \Value.x
                ), SchemaCoding.Support.ObjectPropertyTypeMetadata(
                  name: "y",
                  keyPath: \Value.y
                ))
            }
            typealias Properties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
            static func create(from properties: Properties) -> Self {
              Self(
                properties.0, properties.1
              )
            }
            func properties() -> Properties {
              (__macro_local_1xfMu0_, __macro_local_1yfMu0_)
            }
            typealias PropertyValues = (Int, Int)
            static func value(from propertyValues: PropertyValues) throws -> Value {
              let value = Value(
                x: propertyValues.0, y: propertyValues.1
              )
              return value
            }
            static func propertyValues(from value: Value) -> PropertyValues {
              (value.x, value.y)
            }
            typealias MetaSchema = SchemaCoding.Support.ObjectMetaSchema<Self, __macro_local_1xfMu_, __macro_local_1yfMu_>
            var metaSchema: MetaSchema {
              _metaSchema()
            }
            func initialValueForDecoding(isMutable: Bool) -> Value? {
              _initialValueForDecoding(isMutable: isMutable)
            }
            var metadata = SchemaCoding.Support.SchemaMetadata()
            private let __macro_local_1xfMu0_: __macro_local_1xfMu_
            private let __macro_local_1yfMu0_: __macro_local_1yfMu_
            init() {
              self.__macro_local_1xfMu0_ = __macro_local_1xfMu_(schema: Int.schema)
              self.__macro_local_1yfMu0_ = __macro_local_1yfMu_(schema: Int.schema)
            }
            private init(_ __macro_local_1xfMu0_: __macro_local_1xfMu_, _ __macro_local_1yfMu0_: __macro_local_1yfMu_) {
              self.__macro_local_1xfMu0_ = __macro_local_1xfMu0_
              self.__macro_local_1yfMu0_ = __macro_local_1yfMu0_
            }
          }
        }
        """#,
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

}
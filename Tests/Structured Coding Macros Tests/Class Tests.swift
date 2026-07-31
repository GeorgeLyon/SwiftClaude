import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Verifies that `@StructuredCodable` lowers classes onto `StructuredObject`
/// through the same generation path as structs. The only difference is the
/// decoder initializer: a stored-property-assigning initializer is designated,
/// and designated (and `required`) initializers cannot be declared in an
/// extension — so the macro's member role emits it into the class body, marked
/// `required` so the extension's `decode` can construct through the `Self`
/// metatype. Classes must be `final`: the conformance's protocol-extension
/// members are rooted in the concrete class type, which subclasses could not
/// satisfy.
@Suite
struct StructuredCodableClassTests {

  /// Required, optional, constant, and default-initialized properties: the
  /// extension is identical to a struct's minus the initializer, which lands
  /// in the class body as `required init`.
  @Test
  func classWithAllPropertyKinds() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      final class Counter {
        let id: Int
        var label: String
        var note: String?
        let kind: String = "counter"
        var count: Int = 10
      }
      """,
      #"""
      final class Counter {
        let id: Int
        var label: String
        var note: String?
        let kind: String = "counter"
        var count: Int = 10

        required init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.id = objectDecoder.values.0
          self.label = objectDecoder.values.1
          self.note = objectDecoder.values.2
          // `kind` is a default-initialized `let`; its declared value is kept.
          if let count = objectDecoder.values.4 {
            self.count = count
          }
        }
      }

      extension Counter: StructuredCoding.StructuredObject, StructuredCoding.StructuredObjectRepresentable {
        typealias __macro_local_4RootfMu0_ = Counter
        typealias __macro_local_2idfMu0_ = StructuredCoding.StructuredObjectProperty<__macro_local_4RootfMu0_, Int._StructuredObjectPropertyDefinition>
        typealias __macro_local_5labelfMu0_ = StructuredCoding.StructuredObjectProperty<__macro_local_4RootfMu0_, String._StructuredObjectPropertyDefinition>
        typealias __macro_local_4notefMu0_ = StructuredCoding.StructuredObjectProperty<__macro_local_4RootfMu0_, String?._StructuredObjectPropertyDefinition>
        typealias __macro_local_4kindfMu0_ = StructuredCoding.StructuredObjectProperty<__macro_local_4RootfMu0_, StructuredCoding.StructuredImmutableDefaultInitializedPropertyDefinition<String._StructuredObjectPropertyDefinition>>
        typealias __macro_local_5countfMu0_ = StructuredCoding.StructuredObjectProperty<__macro_local_4RootfMu0_, StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition<Int._StructuredObjectPropertyDefinition>>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = (__macro_local_2idfMu0_, __macro_local_5labelfMu0_, __macro_local_4notefMu0_, __macro_local_4kindfMu0_, __macro_local_5countfMu0_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_2idfMu0_(
              name: "id",
              keyPath: \.id,
              schema: __macro_local_2idfMu0_.Definition.CodingValue.schema
            ), __macro_local_5labelfMu0_(
              name: "label",
              keyPath: \.label,
              schema: __macro_local_5labelfMu0_.Definition.CodingValue.schema
            ), __macro_local_4notefMu0_(
              name: "note",
              keyPath: \.note,
              schema: __macro_local_4notefMu0_.Definition.CodingValue.schema
            ), __macro_local_4kindfMu0_(
              name: "kind",
              keyPath: \.kind,
              schema: __macro_local_4kindfMu0_.Definition.CodingValue.schema
            ), __macro_local_5countfMu0_(
              name: "count",
              keyPath: \.count,
              schema: __macro_local_5countfMu0_.Definition.CodingValue.schema
            ))
        }
        typealias ObjectDecoderValues = (__macro_local_2idfMu0_.ObjectDecoderValue, __macro_local_5labelfMu0_.ObjectDecoderValue, __macro_local_4notefMu0_.ObjectDecoderValue, __macro_local_4kindfMu0_.ObjectDecoderValue, __macro_local_5countfMu0_.ObjectDecoderValue)
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
      }
      """#
    )
  }

  /// A public class's required initializer must be as accessible as the class.
  @Test
  func publicClass() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      public final class Point {
        let x: Int
      }
      """,
      #"""
      public final class Point {
        let x: Int

        public required init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.x = objectDecoder.values
        }
      }

      extension Point: StructuredCoding.StructuredObject, StructuredCoding.StructuredObjectRepresentable {
        public typealias __macro_local_4RootfMu0_ = Point
        public typealias __macro_local_1xfMu0_ = StructuredCoding.StructuredObjectProperty<__macro_local_4RootfMu0_, Int._StructuredObjectPropertyDefinition>
        public static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        public typealias StructuredObjectProperties = __macro_local_1xfMu0_
        public static func properties() -> StructuredObjectProperties {
          __macro_local_1xfMu0_(
            name: "x",
            keyPath: \.x,
            schema: __macro_local_1xfMu0_.Definition.CodingValue.schema
          )
        }
        public typealias ObjectDecoderValues = __macro_local_1xfMu0_.ObjectDecoderValue
        public static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
      }
      """#
    )
  }

  /// A non-final class is rejected with a single diagnostic and no expansion.
  @Test
  func nonFinalClassIsRejected() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      class Counter {
        let id: Int
      }
      """,
      """
      class Counter {
        let id: Int
      }
      """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "@StructuredCodable requires classes to be final: the generated conformance is rooted in the concrete class type and cannot be inherited by subclasses.",
          line: 2,
          column: 7
        )
      ]
    )
  }

}

import Testing

/// Verifies that `@SchemaCodable` lowers structs (and classes) onto
/// `StructuredObject`, matching the hand-written fixtures in
/// `Tests/Structured Coding Tests`.
@Suite
struct SchemaCodableStructTests {

  /// Two required (`let`) properties.
  @Test
  func structWithTwoProperties() {
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
      struct Point {
        let x: Int
        let y: Int
      }
      """,
      #"""
      struct Point {
        let x: Int
        let y: Int
      }

      extension Point: SchemaCoding.StructuredObject {
        typealias __macro_local_1xfMu_ = SchemaCoding.StructuredObjectProperty<Self, SchemaCoding.StructuredRequiredObjectPropertyDefinition<Int>>
        typealias __macro_local_1yfMu_ = SchemaCoding.StructuredObjectProperty<Self, SchemaCoding.StructuredRequiredObjectPropertyDefinition<Int>>
        typealias Properties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
        static func properties() -> Properties {
          (__macro_local_1xfMu_(
              name: "x",
              keyPath: \.x
            ), __macro_local_1yfMu_(
              name: "y",
              keyPath: \.y
            ))
        }
        typealias ObjectDecoderValues = (__macro_local_1xfMu_.ObjectDecoderValue, __macro_local_1yfMu_.ObjectDecoderValue)
        static func decode(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.x = objectDecoder.values.0
          self.y = objectDecoder.values.1
        }
      }
      """#
    )
  }

  /// Optional, constant (`let = …`, omitted from `decode`), and default-initialized
  /// (`var = …`, `?? default` in `decode`) properties.
  @Test
  func structWithOptionalsAndDefaults() {
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
      struct S {
        var first: String
        var second: String?
        let kind: String = "fixed"
        var count: Int = 10
      }
      """,
      #"""
      struct S {
        var first: String
        var second: String?
        let kind: String = "fixed"
        var count: Int = 10
      }

      extension S: SchemaCoding.StructuredObject {
        typealias __macro_local_5firstfMu_ = SchemaCoding.StructuredObjectProperty<Self, SchemaCoding.StructuredRequiredObjectPropertyDefinition<String>>
        typealias __macro_local_6secondfMu_ = SchemaCoding.StructuredObjectProperty<Self, SchemaCoding.StructuredOptionalObjectPropertyDefinition<String>>
        typealias __macro_local_4kindfMu_ = SchemaCoding.StructuredObjectProperty<Self, SchemaCoding.StructuredImmutableDefaultInitializedPropertyDefinition<SchemaCoding.StructuredRequiredObjectPropertyDefinition<String>>>
        typealias __macro_local_5countfMu_ = SchemaCoding.StructuredObjectProperty<Self, SchemaCoding.StructuredMutableDefaultInitializedPropertyDefinition<SchemaCoding.StructuredRequiredObjectPropertyDefinition<Int>>>
        typealias Properties = (__macro_local_5firstfMu_, __macro_local_6secondfMu_, __macro_local_4kindfMu_, __macro_local_5countfMu_)
        static func properties() -> Properties {
          (__macro_local_5firstfMu_(
              name: "first",
              keyPath: \.first
            ), __macro_local_6secondfMu_(
              name: "second",
              keyPath: \.second
            ), __macro_local_4kindfMu_(
              name: "kind",
              keyPath: \.kind
            ), __macro_local_5countfMu_(
              name: "count",
              keyPath: \.count
            ))
        }
        typealias ObjectDecoderValues = (__macro_local_5firstfMu_.ObjectDecoderValue, __macro_local_6secondfMu_.ObjectDecoderValue, __macro_local_4kindfMu_.ObjectDecoderValue, __macro_local_5countfMu_.ObjectDecoderValue)
        static func decode(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.first = objectDecoder.values.0
          self.second = objectDecoder.values.1
          // `kind` is a default-initialized `let`; its declared value is kept.
          if let count = objectDecoder.values.3 {
            self.count = count
          }
        }
      }
      """#
    )
  }

  /// A single property collapses the tuple — `Properties`/`ObjectDecoderValues`
  /// are bare and `decode` reads `objectDecoder.values` directly.
  @Test
  func structWithSingleProperty() {
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
      struct Single {
        let value: Int
      }
      """,
      #"""
      struct Single {
        let value: Int
      }

      extension Single: SchemaCoding.StructuredObject {
        typealias __macro_local_5valuefMu_ = SchemaCoding.StructuredObjectProperty<Self, SchemaCoding.StructuredRequiredObjectPropertyDefinition<Int>>
        typealias Properties = __macro_local_5valuefMu_
        static func properties() -> Properties {
          __macro_local_5valuefMu_(
            name: "value",
            keyPath: \.value
          )
        }
        typealias ObjectDecoderValues = __macro_local_5valuefMu_.ObjectDecoderValue
        static func decode(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.value = objectDecoder.values
        }
      }
      """#
    )
  }

  /// No properties — empty tuples and `Self()`.
  @Test
  func emptyStruct() {
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
      struct Empty {
      }
      """,
      #"""
      struct Empty {
      }

      extension Empty: SchemaCoding.StructuredObject {
        typealias Properties = ()
        static func properties() -> Properties {
          ()
        }
        typealias ObjectDecoderValues = ()
        static func decode(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending SchemaCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
        }
      }
      """#
    )
  }

}

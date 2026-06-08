import Testing

/// Verifies that `@StructuredCodable` lowers structs (and classes) onto
/// `StructuredObject`, matching the hand-written fixtures in
/// `Tests/Structured Coding Tests`.
@Suite
struct StructuredCodableStructTests {

  /// Two required (`let`) properties.
  @Test
  func structWithTwoProperties() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
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

      extension Point: StructuredCoding.StructuredObject {
        typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
        typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
        typealias Schema = StructuredCoding.StructuredObjectSchema<Self, __macro_local_1xfMu_.Definition, __macro_local_1yfMu_.Definition>
        typealias StructuredObjectProperties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_1xfMu_(
              name: "x",
              keyPath: \.x,
              schema: __macro_local_1xfMu_.CodingSchema()
            ), __macro_local_1yfMu_(
              name: "y",
              keyPath: \.y,
              schema: __macro_local_1yfMu_.CodingSchema()
            ))
        }
        typealias ObjectDecoderValues = (__macro_local_1xfMu_.ObjectDecoderValue, __macro_local_1yfMu_.ObjectDecoderValue)
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
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
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
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

      extension S: StructuredCoding.StructuredObject {
        typealias __macro_local_5firstfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<String>>
        typealias __macro_local_6secondfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredOptionalObjectPropertyDefinition<String>>
        typealias __macro_local_4kindfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredImmutableDefaultInitializedPropertyDefinition<StructuredCoding.StructuredRequiredObjectPropertyDefinition<String>>>
        typealias __macro_local_5countfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition<StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>>
        typealias Schema = StructuredCoding.StructuredObjectSchema<Self, __macro_local_5firstfMu_.Definition, __macro_local_6secondfMu_.Definition, __macro_local_4kindfMu_.Definition, __macro_local_5countfMu_.Definition>
        typealias StructuredObjectProperties = (__macro_local_5firstfMu_, __macro_local_6secondfMu_, __macro_local_4kindfMu_, __macro_local_5countfMu_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_5firstfMu_(
              name: "first",
              keyPath: \.first,
              schema: __macro_local_5firstfMu_.CodingSchema()
            ), __macro_local_6secondfMu_(
              name: "second",
              keyPath: \.second,
              schema: __macro_local_6secondfMu_.CodingSchema()
            ), __macro_local_4kindfMu_(
              name: "kind",
              keyPath: \.kind,
              schema: __macro_local_4kindfMu_.CodingSchema()
            ), __macro_local_5countfMu_(
              name: "count",
              keyPath: \.count,
              schema: __macro_local_5countfMu_.CodingSchema()
            ))
        }
        typealias ObjectDecoderValues = (__macro_local_5firstfMu_.ObjectDecoderValue, __macro_local_6secondfMu_.ObjectDecoderValue, __macro_local_4kindfMu_.ObjectDecoderValue, __macro_local_5countfMu_.ObjectDecoderValue)
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
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
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      struct Single {
        let value: Int
      }
      """,
      #"""
      struct Single {
        let value: Int
      }

      extension Single: StructuredCoding.StructuredObject {
        typealias __macro_local_5valuefMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
        typealias Schema = StructuredCoding.StructuredObjectSchema<Self, __macro_local_5valuefMu_.Definition>
        typealias StructuredObjectProperties = __macro_local_5valuefMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_5valuefMu_(
            name: "value",
            keyPath: \.value,
            schema: __macro_local_5valuefMu_.CodingSchema()
          )
        }
        typealias ObjectDecoderValues = __macro_local_5valuefMu_.ObjectDecoderValue
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.value = objectDecoder.values
        }
      }
      """#
    )
  }

  /// No properties — empty tuples and `Self()`.
  /// `compatibilityMode: .variadicGenerics` accesses every property through a
  /// getter closure instead of a key path literal, so the conformance can be
  /// generated for pack-generic types (key paths rooted in them crash at
  /// runtime; see `StructuredCodingCompatibilityMode.variadicGenerics`).
  @Test
  func structWithVariadicGenericsCompatibilityMode() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(compatibilityMode: .variadicGenerics)
      struct PackBox<each T> {
        var first: String
        var second: String?
      }
      """,
      #"""
      struct PackBox<each T> {
        var first: String
        var second: String?
      }

      extension PackBox: StructuredCoding.StructuredObject {
        typealias __macro_local_5firstfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<String>>
        typealias __macro_local_6secondfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredOptionalObjectPropertyDefinition<String>>
        typealias Schema = StructuredCoding.StructuredObjectSchema<Self, __macro_local_5firstfMu_.Definition, __macro_local_6secondfMu_.Definition>
        typealias StructuredObjectProperties = (__macro_local_5firstfMu_, __macro_local_6secondfMu_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_5firstfMu_(
              name: "first",
              getter: {
                $0.first
              },
              schema: __macro_local_5firstfMu_.CodingSchema()
            ), __macro_local_6secondfMu_(
              name: "second",
              getter: {
                $0.second
              },
              schema: __macro_local_6secondfMu_.CodingSchema()
            ))
        }
        typealias ObjectDecoderValues = (__macro_local_5firstfMu_.ObjectDecoderValue, __macro_local_6secondfMu_.ObjectDecoderValue)
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.first = objectDecoder.values.0
          self.second = objectDecoder.values.1
        }
      }
      """#
    )
  }

  /// `.omitSchema` makes the `Schema` typealias the concrete
  /// `StructuredAnySchema` instead of a structural schema — the structural
  /// schema's witness mangling crashes the runtime demangler for pack-generic
  /// types. Also covers the array-literal form of `compatibilityMode:`.
  @Test
  func structWithOmitSchemaCompatibilityMode() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(compatibilityMode: [.variadicGenerics, .omitSchema])
      struct PackBox<each T> {
        var first: String
      }
      """,
      #"""
      struct PackBox<each T> {
        var first: String
      }

      extension PackBox: StructuredCoding.StructuredObject {
        typealias __macro_local_5firstfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<String>>
        typealias Schema = StructuredCoding.StructuredAnySchema
        typealias StructuredObjectProperties = __macro_local_5firstfMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_5firstfMu_(
            name: "first",
            getter: {
              $0.first
            },
            schema: __macro_local_5firstfMu_.CodingSchema()
          )
        }
        typealias ObjectDecoderValues = __macro_local_5firstfMu_.ObjectDecoderValue
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.first = objectDecoder.values
        }
      }
      """#
    )
  }

  @Test
  func emptyStruct() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      struct Empty {
      }
      """,
      #"""
      struct Empty {
      }

      extension Empty: StructuredCoding.StructuredObject {
        typealias Schema = StructuredCoding.StructuredObjectSchema<Self>
        typealias StructuredObjectProperties = ()
        static func properties() -> StructuredObjectProperties {
          ()
        }
        typealias ObjectDecoderValues = ()
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
        }
      }
      """#
    )
  }

}

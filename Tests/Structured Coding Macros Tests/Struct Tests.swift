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
        typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
        typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_1xfMu_(
              name: "x",
              keyPath: \.x,
              schema: __macro_local_1xfMu_.Definition.CodingValue.schema
            ), __macro_local_1yfMu_(
              name: "y",
              keyPath: \.y,
              schema: __macro_local_1yfMu_.Definition.CodingValue.schema
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
        typealias __macro_local_5firstfMu_ = StructuredCoding.StructuredObjectProperty<Self, String._StructuredObjectPropertyDefinition>
        typealias __macro_local_6secondfMu_ = StructuredCoding.StructuredObjectProperty<Self, Swift.Optional<String>._StructuredObjectPropertyDefinition>
        typealias __macro_local_4kindfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredImmutableDefaultInitializedPropertyDefinition<String._StructuredObjectPropertyDefinition>>
        typealias __macro_local_5countfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition<Int._StructuredObjectPropertyDefinition>>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = (__macro_local_5firstfMu_, __macro_local_6secondfMu_, __macro_local_4kindfMu_, __macro_local_5countfMu_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_5firstfMu_(
              name: "first",
              keyPath: \.first,
              schema: __macro_local_5firstfMu_.Definition.CodingValue.schema
            ), __macro_local_6secondfMu_(
              name: "second",
              keyPath: \.second,
              schema: __macro_local_6secondfMu_.Definition.CodingValue.schema
            ), __macro_local_4kindfMu_(
              name: "kind",
              keyPath: \.kind,
              schema: __macro_local_4kindfMu_.Definition.CodingValue.schema
            ), __macro_local_5countfMu_(
              name: "count",
              keyPath: \.count,
              schema: __macro_local_5countfMu_.Definition.CodingValue.schema
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
        typealias __macro_local_5valuefMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = __macro_local_5valuefMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_5valuefMu_(
            name: "value",
            keyPath: \.value,
            schema: __macro_local_5valuefMu_.Definition.CodingValue.schema
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
        typealias __macro_local_5firstfMu_ = StructuredCoding.StructuredObjectProperty<Self, String._StructuredObjectPropertyDefinition>
        typealias __macro_local_6secondfMu_ = StructuredCoding.StructuredObjectProperty<Self, Swift.Optional<String>._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = (__macro_local_5firstfMu_, __macro_local_6secondfMu_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_5firstfMu_(
              name: "first",
              getter: {
                $0.first
              },
              schema: __macro_local_5firstfMu_.Definition.CodingValue.schema
            ), __macro_local_6secondfMu_(
              name: "second",
              getter: {
                $0.second
              },
              schema: __macro_local_6secondfMu_.Definition.CodingValue.schema
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

  /// Covers the array-literal form of `compatibilityMode:` (`[.variadicGenerics]`
  /// rather than the bare `.variadicGenerics`). A type-erased
  /// `schema` witness is emitted instead of a structural `Schema` typealias.
  @Test
  func structWithArrayLiteralCompatibilityMode() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(compatibilityMode: [.variadicGenerics])
      struct PackBox<each T> {
        var first: String
      }
      """,
      #"""
      struct PackBox<each T> {
        var first: String
      }

      extension PackBox: StructuredCoding.StructuredObject {
        typealias __macro_local_5firstfMu_ = StructuredCoding.StructuredObjectProperty<Self, String._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = __macro_local_5firstfMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_5firstfMu_(
            name: "first",
            getter: {
              $0.first
            },
            schema: __macro_local_5firstfMu_.Definition.CodingValue.schema
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

  /// `@StructuredCodable(description:)` passes its description to `_schema`
  /// as `typeDescription:`; use sites prepend theirs onto the resulting schema.
  @Test
  func structWithTypeDescription() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(description: "A 2D point")
      struct Point {
        let x: Int
      }
      """,
      #"""
      struct Point {
        let x: Int
      }

      extension Point: StructuredCoding.StructuredObject {
        typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema(typeDescription: "A 2D point")
        }
        typealias StructuredObjectProperties = __macro_local_1xfMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_1xfMu_(
            name: "x",
            keyPath: \.x,
            schema: __macro_local_1xfMu_.Definition.CodingValue.schema
          )
        }
        typealias ObjectDecoderValues = __macro_local_1xfMu_.ObjectDecoderValue
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.x = objectDecoder.values
        }
      }
      """#
    )
  }

  /// `@StructuredProperty(description:)` becomes a `description:` argument on
  /// the property descriptor, whose initializer prepends it onto the
  /// property's schema; unannotated properties omit the argument.
  @Test
  func structWithPropertyDescription() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      struct Point {
        @StructuredProperty(description: "The horizontal coordinate")
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
        typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
        typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<Self, Int._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
        static func properties() -> StructuredObjectProperties {
          (__macro_local_1xfMu_(
              name: "x",
              description: "The horizontal coordinate",
              keyPath: \.x,
              schema: __macro_local_1xfMu_.Definition.CodingValue.schema
            ), __macro_local_1yfMu_(
              name: "y",
              keyPath: \.y,
              schema: __macro_local_1yfMu_.Definition.CodingValue.schema
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

  /// `style: .wrapper` generates the same members as a single-property object
  /// but conforms to `StructuredWrapper`, whose protocol extensions code the
  /// struct as its bare stored value.
  @Test
  func wrapperStruct() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(style: .wrapper)
      struct MediaType {
        let stringValue: String
      }
      """,
      #"""
      struct MediaType {
        let stringValue: String
      }

      extension MediaType: StructuredCoding.StructuredWrapper {
        typealias __macro_local_11stringValuefMu_ = StructuredCoding.StructuredObjectProperty<Self, String._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = __macro_local_11stringValuefMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_11stringValuefMu_(
            name: "stringValue",
            keyPath: \.stringValue,
            schema: __macro_local_11stringValuefMu_.Definition.CodingValue.schema
          )
        }
        typealias ObjectDecoderValues = __macro_local_11stringValuefMu_.ObjectDecoderValue
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.stringValue = objectDecoder.values
        }
      }
      """#
    )
  }

  /// An optional wrapped value lowers exactly like any other property — the
  /// wrapper-specific semantics (coding by `Optional`'s own conformance,
  /// since there is no enclosing object to omit a `nil` from) come from the
  /// optional-cored `StructuredWrapper` extension, not the expansion.
  @Test
  func wrapperStructWithOptionalValue() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(style: .wrapper)
      struct MaybeName {
        let name: String?
      }
      """,
      #"""
      struct MaybeName {
        let name: String?
      }

      extension MaybeName: StructuredCoding.StructuredWrapper {
        typealias __macro_local_4namefMu_ = StructuredCoding.StructuredObjectProperty<Self, Swift.Optional<String>._StructuredObjectPropertyDefinition>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = __macro_local_4namefMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_4namefMu_(
            name: "name",
            keyPath: \.name,
            schema: __macro_local_4namefMu_.Definition.CodingValue.schema
          )
        }
        typealias ObjectDecoderValues = __macro_local_4namefMu_.ObjectDecoderValue
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          self.name = objectDecoder.values
        }
      }
      """#
    )
  }

  /// Defaults lower exactly as they do for objects — the property definitions
  /// carry their semantics (a `var` default re-seeds before streaming and
  /// falls back in the decode initializer).
  @Test
  func wrapperStructWithDefaultedVar() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(style: .wrapper)
      struct Tag {
        var text: String = "untagged"
      }
      """,
      #"""
      struct Tag {
        var text: String = "untagged"
      }

      extension Tag: StructuredCoding.StructuredWrapper {
        typealias __macro_local_4textfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition<String._StructuredObjectPropertyDefinition>>
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias StructuredObjectProperties = __macro_local_4textfMu_
        static func properties() -> StructuredObjectProperties {
          __macro_local_4textfMu_(
            name: "text",
            keyPath: \.text,
            schema: __macro_local_4textfMu_.Definition.CodingValue.schema
          )
        }
        typealias ObjectDecoderValues = __macro_local_4textfMu_.ObjectDecoderValue
        static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
          Self(from: objectDecoder)
        }
        private init(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) {
          if let text = objectDecoder.values {
            self.text = text
          }
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
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
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

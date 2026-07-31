import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// Verifies that `@StructuredCodable` lowers enums onto `StructuredEnumeration`,
/// matching the hand-written fixtures in `Tests/Structured Coding Tests`.
@Suite
struct StructuredCodableEnumTests {

  /// Defaulted associated values lower like `var x: T = expr` struct
  /// properties: the `Mutable` definition wrapper plus a `?? default` decode
  /// fallback — the same rules `@StructuredAction` applies to defaulted
  /// function parameters.
  @Test
  func enumDefaultedAssociatedValues() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      enum Policy {
        case retry(count: Int = 3, delay: Double? = nil)
      }
      """,
      #"""
      enum Policy {
        case retry(count: Int = 3, delay: Double? = nil)
      }

      extension Policy: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = StructuredCoding.StructuredEnumerationCase<Self, __macro_local_5retryfMu_>
        static func cases() -> Cases {
          StructuredCoding.StructuredEnumerationCase(
            name: "retry",
            accessor: { value in
              guard case .retry(let v0, let v1) = value else {
                return nil
              }
              return __macro_local_5retryfMu_(count: v0, delay: v1)
            },
            initializer: {
              .retry(count: $0.count, delay: $0.delay)
            }
          )
        }
        struct __macro_local_5retryfMu_: StructuredCoding.StructuredObject {
          var count: Int
          var delay: Double?
          typealias __macro_local_5countfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_5retryfMu_, StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition<Int._StructuredObjectPropertyDefinition>>
          typealias __macro_local_5delayfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_5retryfMu_, StructuredCoding.StructuredMutableDefaultInitializedPropertyDefinition<Double?._StructuredObjectPropertyDefinition>>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = (__macro_local_5countfMu_, __macro_local_5delayfMu_)
          static func properties() -> StructuredObjectProperties {
            (__macro_local_5countfMu_(
                name: "count",
                keyPath: \.count,
                schema: __macro_local_5countfMu_.Definition.CodingValue.schema
              ), __macro_local_5delayfMu_(
                name: "delay",
                keyPath: \.delay,
                schema: __macro_local_5delayfMu_.Definition.CodingValue.schema
              ))
          }
          typealias ObjectDecoderValues = (__macro_local_5countfMu_.ObjectDecoderValue, __macro_local_5delayfMu_.ObjectDecoderValue)
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              count: objectDecoder.values.0 ?? 3,
              delay: objectDecoder.values.1 ?? nil
            )
          }
        }
      }
      """#
    )
  }

  /// Default object-properties style: single-value cases, plus a value-less case
  /// represented by `StructuredEmptyObject`.
  @Test
  func enumObjectProperties() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      enum E {
        case text(String)
        case count(Int)
        case ping
      }
      """,
      #"""
      enum E {
        case text(String)
        case count(Int)
        case ping
      }

      extension E: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = (StructuredCoding.StructuredEnumerationCase<Self, String>, StructuredCoding.StructuredEnumerationCase<Self, Int>, StructuredCoding.StructuredEnumerationCase<Self, StructuredCoding.StructuredEmptyObject>)
        static func cases() -> Cases {
          (StructuredCoding.StructuredEnumerationCase(
              name: "text",
              accessor: { value in
                guard case .text(let v0) = value else {
                  return nil
                }
                return v0
              },
              initializer: {
                .text($0)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "count",
              accessor: { value in
                guard case .count(let v0) = value else {
                  return nil
                }
                return v0
              },
              initializer: {
                .count($0)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "ping",
              accessor: { value in
                guard case .ping = value else {
                  return nil
                }
                return StructuredCoding.StructuredEmptyObject()
              },
              initializer: { _ in
                .ping
              }
            ))
        }
      }
      """#
    )
  }

  /// Multi-value cases with at least one unlabeled value collapse onto a
  /// `StructuredTuple`; case labels are preserved on reconstruction.
  @Test
  func enumTupleCases() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      enum T {
        case pair(Int, String)
        case mixed(Int, label: String)
      }
      """,
      #"""
      enum T {
        case pair(Int, String)
        case mixed(Int, label: String)
      }

      extension T: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = (StructuredCoding.StructuredEnumerationCase<Self, StructuredCoding.StructuredTuple<Int, String>>, StructuredCoding.StructuredEnumerationCase<Self, StructuredCoding.StructuredTuple<Int, String>>)
        static func cases() -> Cases {
          (StructuredCoding.StructuredEnumerationCase(
              name: "pair",
              accessor: { value in
                guard case .pair(let v0, let v1) = value else {
                  return nil
                }
                return StructuredCoding.StructuredTuple(v0, v1)
              },
              initializer: {
                .pair($0.values.0, $0.values.1)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "mixed",
              accessor: { value in
                guard case .mixed(let v0, let v1) = value else {
                  return nil
                }
                return StructuredCoding.StructuredTuple(v0, v1)
              },
              initializer: {
                .mixed($0.values.0, label: $0.values.1)
              }
            ))
        }
      }
      """#
    )
  }

  /// An all-labeled multi-value case is wrapped in a synthesized `StructuredObject`
  /// nested in the conformance.
  @Test
  func enumAllLabeledCase() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      enum O {
        case point(x: Int, y: Int)
      }
      """,
      #"""
      enum O {
        case point(x: Int, y: Int)
      }

      extension O: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = StructuredCoding.StructuredEnumerationCase<Self, __macro_local_5pointfMu_>
        static func cases() -> Cases {
          StructuredCoding.StructuredEnumerationCase(
            name: "point",
            accessor: { value in
              guard case .point(let v0, let v1) = value else {
                return nil
              }
              return __macro_local_5pointfMu_(x: v0, y: v1)
            },
            initializer: {
              .point(x: $0.x, y: $0.y)
            }
          )
        }
        struct __macro_local_5pointfMu_: StructuredCoding.StructuredObject {
          var x: Int
          var y: Int
          typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_5pointfMu_, Int._StructuredObjectPropertyDefinition>
          typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_5pointfMu_, Int._StructuredObjectPropertyDefinition>
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
            Self(
              x: objectDecoder.values.0,
              y: objectDecoder.values.1
            )
          }
        }
      }
      """#
    )
  }

  /// `internallyTagged` emits a `codingConfiguration` member.
  @Test
  func enumInternallyTagged() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(style: .internallyTagged(discriminatorPropertyName: "type"))
      enum Event {
        case message(Message)
        case move(x: Int, y: Int)
      }
      """,
      #"""
      enum Event {
        case message(Message)
        case move(x: Int, y: Int)
      }

      extension Event: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var codingConfiguration: StructuredCoding.StructuredEnumerationCodingConfiguration<StructuredCoding.StructuredEnumerationCodingStyleInternallyTagged> {
          .init(style: .internallyTagged(discriminatorPropertyName: "type"))
        }
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = (StructuredCoding.StructuredEnumerationCase<Self, Message>, StructuredCoding.StructuredEnumerationCase<Self, __macro_local_4movefMu_>)
        static func cases() -> Cases {
          (StructuredCoding.StructuredEnumerationCase(
              name: "message",
              accessor: { value in
                guard case .message(let v0) = value else {
                  return nil
                }
                return v0
              },
              initializer: {
                .message($0)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "move",
              accessor: { value in
                guard case .move(let v0, let v1) = value else {
                  return nil
                }
                return __macro_local_4movefMu_(x: v0, y: v1)
              },
              initializer: {
                .move(x: $0.x, y: $0.y)
              }
            ))
        }
        struct __macro_local_4movefMu_: StructuredCoding.StructuredObject {
          var x: Int
          var y: Int
          typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_4movefMu_, Int._StructuredObjectPropertyDefinition>
          typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_4movefMu_, Int._StructuredObjectPropertyDefinition>
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
            Self(
              x: objectDecoder.values.0,
              y: objectDecoder.values.1
            )
          }
        }
      }
      """#
    )
  }

  /// A case with a single labeled value synthesizes a one-property payload
  /// object in every style — here internally tagged, where the object is what
  /// gives the discriminator a place to live.
  @Test
  func enumInternallyTaggedSingleLabeledValue() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(style: .internallyTagged(discriminatorPropertyName: "kind"))
      enum Shape {
        case circle(radius: Double)
      }
      """,
      #"""
      enum Shape {
        case circle(radius: Double)
      }

      extension Shape: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var codingConfiguration: StructuredCoding.StructuredEnumerationCodingConfiguration<StructuredCoding.StructuredEnumerationCodingStyleInternallyTagged> {
          .init(style: .internallyTagged(discriminatorPropertyName: "kind"))
        }
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = StructuredCoding.StructuredEnumerationCase<Self, __macro_local_6circlefMu_>
        static func cases() -> Cases {
          StructuredCoding.StructuredEnumerationCase(
            name: "circle",
            accessor: { value in
              guard case .circle(let v0) = value else {
                return nil
              }
              return __macro_local_6circlefMu_(radius: v0)
            },
            initializer: {
              .circle(radius: $0.radius)
            }
          )
        }
        struct __macro_local_6circlefMu_: StructuredCoding.StructuredObject {
          var radius: Double
          typealias __macro_local_6radiusfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_6circlefMu_, Double._StructuredObjectPropertyDefinition>
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = __macro_local_6radiusfMu_
          static func properties() -> StructuredObjectProperties {
            __macro_local_6radiusfMu_(
              name: "radius",
              keyPath: \.radius,
              schema: __macro_local_6radiusfMu_.Definition.CodingValue.schema
            )
          }
          typealias ObjectDecoderValues = __macro_local_6radiusfMu_.ObjectDecoderValue
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self(
              radius: objectDecoder.values
            )
          }
        }
      }
      """#
    )
  }

  /// `typeDiscriminated` emits a `codingConfiguration` member.
  @Test
  func enumTypeDiscriminated() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(style: .typeDiscriminated)
      enum Node {
        case string(String)
        case point(x: Int, y: Int)
      }
      """,
      #"""
      enum Node {
        case string(String)
        case point(x: Int, y: Int)
      }

      extension Node: StructuredCoding.StructuredEnumeration {
        static var codingConfiguration: StructuredCoding.StructuredEnumerationCodingConfiguration<StructuredCoding.StructuredEnumerationCodingStyleTypeDiscriminated> {
          .init(style: .typeDiscriminated)
        }
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = (StructuredCoding.StructuredEnumerationCase<Self, String>, StructuredCoding.StructuredEnumerationCase<Self, __macro_local_5pointfMu_>)
        static func cases() -> Cases {
          (StructuredCoding.StructuredEnumerationCase(
              name: "string",
              accessor: { value in
                guard case .string(let v0) = value else {
                  return nil
                }
                return v0
              },
              initializer: {
                .string($0)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "point",
              accessor: { value in
                guard case .point(let v0, let v1) = value else {
                  return nil
                }
                return __macro_local_5pointfMu_(x: v0, y: v1)
              },
              initializer: {
                .point(x: $0.x, y: $0.y)
              }
            ))
        }
        struct __macro_local_5pointfMu_: StructuredCoding.StructuredObject {
          var x: Int
          var y: Int
          typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_5pointfMu_, Int._StructuredObjectPropertyDefinition>
          typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_5pointfMu_, Int._StructuredObjectPropertyDefinition>
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
            Self(
              x: objectDecoder.values.0,
              y: objectDecoder.values.1
            )
          }
        }
      }
      """#
    )
  }

  /// `@StructuredCase(description:)` adds a `description:` argument to the
  /// generated `StructuredEnumerationCase`; unannotated cases omit it.
  @Test
  func enumCaseDescription() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      enum E {
        @StructuredCase(description: "A text message")
        case text(String)
        case ping
      }
      """,
      #"""
      enum E {
        case text(String)
        case ping
      }

      extension E: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = (StructuredCoding.StructuredEnumerationCase<Self, String>, StructuredCoding.StructuredEnumerationCase<Self, StructuredCoding.StructuredEmptyObject>)
        static func cases() -> Cases {
          (StructuredCoding.StructuredEnumerationCase(
              name: "text",
              description: "A text message",
              accessor: { value in
                guard case .text(let v0) = value else {
                  return nil
                }
                return v0
              },
              initializer: {
                .text($0)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "ping",
              accessor: { value in
                guard case .ping = value else {
                  return nil
                }
                return StructuredCoding.StructuredEmptyObject()
              },
              initializer: { _ in
                .ping
              }
            ))
        }
      }
      """#
    )
  }

  /// `undeclaredPropertyBehavior: .discard` is recorded in the
  /// `codingConfiguration` (even for the default style) and propagated into
  /// every synthesized case payload object. Value-less cases share one
  /// synthesized empty payload object instead of `StructuredEmptyObject`,
  /// which cannot carry the per-enum setting. A single-object case
  /// (`.message`) is untouched — its type's own setting governs.
  @Test
  func enumDiscardingUndeclaredProperties() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(undeclaredPropertyBehavior: .discard)
      enum E {
        case message(Message)
        case note(text: String)
        case ping
      }
      """,
      #"""
      enum E {
        case message(Message)
        case note(text: String)
        case ping
      }

      extension E: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var codingConfiguration: StructuredCoding.StructuredEnumerationCodingConfiguration<StructuredCoding.StructuredEnumerationCodingStyleObjectProperties> {
          .init(style: .objectProperties, undeclaredPropertyBehavior: .discard)
        }
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = (StructuredCoding.StructuredEnumerationCase<Self, Message>, StructuredCoding.StructuredEnumerationCase<Self, __macro_local_4notefMu_>, StructuredCoding.StructuredEnumerationCase<Self, __macro_local_12EmptyPayloadfMu_>)
        static func cases() -> Cases {
          (StructuredCoding.StructuredEnumerationCase(
              name: "message",
              accessor: { value in
                guard case .message(let v0) = value else {
                  return nil
                }
                return v0
              },
              initializer: {
                .message($0)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "note",
              accessor: { value in
                guard case .note(let v0) = value else {
                  return nil
                }
                return __macro_local_4notefMu_(text: v0)
              },
              initializer: {
                .note(text: $0.text)
              }
            ), StructuredCoding.StructuredEnumerationCase(
              name: "ping",
              accessor: { value in
                guard case .ping = value else {
                  return nil
                }
                return __macro_local_12EmptyPayloadfMu_()
              },
              initializer: { _ in
                .ping
              }
            ))
        }
        struct __macro_local_4notefMu_: StructuredCoding.StructuredObject {
          var text: String
          typealias __macro_local_4textfMu_ = StructuredCoding.StructuredObjectProperty<__macro_local_4notefMu_, String._StructuredObjectPropertyDefinition>
          static var undeclaredPropertyBehavior: StructuredCoding.StructuredUndeclaredPropertyBehavior {
            .discard
          }
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
            Self(
              text: objectDecoder.values
            )
          }
        }
        struct __macro_local_12EmptyPayloadfMu_: StructuredCoding.StructuredObject {
          static var undeclaredPropertyBehavior: StructuredCoding.StructuredUndeclaredPropertyBehavior {
            .discard
          }
          static var schema: some StructuredCoding.StructuredCodingSchema {
            _schema()
          }
          typealias StructuredObjectProperties = ()
          static func properties() -> StructuredObjectProperties {
            ()
          }
          typealias ObjectDecoderValues = ()
          static func decode(from objectDecoder: sending StructuredCoding.StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self {
            Self()
          }
        }
      }
      """#
    )
  }

  /// A type-discriminated case codes as its bare associated value — there is
  /// no object container — so spelling `undeclaredPropertyBehavior` on the
  /// enumeration is diagnosed and ignored.
  @Test
  func enumTypeDiscriminatedRejectsUndeclaredPropertyBehavior() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable(style: .typeDiscriminated, undeclaredPropertyBehavior: .discard)
      enum Node {
        case string(String)
      }
      """,
      #"""
      enum Node {
        case string(String)
      }

      extension Node: StructuredCoding.StructuredEnumeration {
        static var codingConfiguration: StructuredCoding.StructuredEnumerationCodingConfiguration<StructuredCoding.StructuredEnumerationCodingStyleTypeDiscriminated> {
          .init(style: .typeDiscriminated)
        }
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = StructuredCoding.StructuredEnumerationCase<Self, String>
        static func cases() -> Cases {
          StructuredCoding.StructuredEnumerationCase(
            name: "string",
            accessor: { value in
              guard case .string(let v0) = value else {
                return nil
              }
              return v0
            },
            initializer: {
              .string($0)
            }
          )
        }
      }
      """#,
      diagnostics: [
        DiagnosticSpec(
          message:
            "`undeclaredPropertyBehavior` cannot be applied to a type-discriminated enumeration, whose cases code as bare values with no object container.",
          line: 2,
          column: 6
        )
      ]
    )
  }

  /// A single case collapses `Cases` to the bare `StructuredEnumerationCase`.
  @Test
  func singleCaseEnum() {
    assertStructuredCodableExpansion(
      """
      @StructuredCodable
      enum Maybe {
        case maybe(Int?)
      }
      """,
      #"""
      enum Maybe {
        case maybe(Int?)
      }

      extension Maybe: StructuredCoding.StructuredEnumeration, StructuredCoding.StructuredObjectRepresentable {
        static var schema: some StructuredCoding.StructuredCodingSchema {
          _schema()
        }
        typealias Cases = StructuredCoding.StructuredEnumerationCase<Self, Int?>
        static func cases() -> Cases {
          StructuredCoding.StructuredEnumerationCase(
            name: "maybe",
            accessor: { value in
              guard case .maybe(let v0) = value else {
                return nil
              }
              return v0
            },
            initializer: {
              .maybe($0)
            }
          )
        }
      }
      """#
    )
  }

}

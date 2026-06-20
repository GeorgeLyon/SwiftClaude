import Testing

/// Verifies that `@StructuredCodable` lowers enums onto `StructuredEnumeration`,
/// matching the hand-written fixtures in `Tests/Structured Coding Tests`.
@Suite
struct StructuredCodableEnumTests {

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

      extension E: StructuredCoding.StructuredEnumeration {
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

      extension T: StructuredCoding.StructuredEnumeration {
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

      extension O: StructuredCoding.StructuredEnumeration {
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
          typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
          typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
          typealias Schema = StructuredCoding.StructuredObjectSchema<Self, __macro_local_1xfMu_.Definition, __macro_local_1yfMu_.Definition>
          typealias StructuredObjectProperties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
          static func properties() -> StructuredObjectProperties {
            (__macro_local_1xfMu_(
                name: "x",
                keyPath: \.x,
                schema: __macro_local_1xfMu_.Definition.CodingValue.schema(description: nil)
              ), __macro_local_1yfMu_(
                name: "y",
                keyPath: \.y,
                schema: __macro_local_1yfMu_.Definition.CodingValue.schema(description: nil)
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

  /// `internallyTagged` emits a `codingStyle` member.
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

      extension Event: StructuredCoding.StructuredEnumeration {
        static var codingStyle: StructuredCoding.StructuredEnumerationCodingStyleInternallyTagged {
          StructuredCoding.StructuredEnumerationCodingStyleInternallyTagged(discriminatorPropertyName: "type")
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
          typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
          typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
          typealias Schema = StructuredCoding.StructuredObjectSchema<Self, __macro_local_1xfMu_.Definition, __macro_local_1yfMu_.Definition>
          typealias StructuredObjectProperties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
          static func properties() -> StructuredObjectProperties {
            (__macro_local_1xfMu_(
                name: "x",
                keyPath: \.x,
                schema: __macro_local_1xfMu_.Definition.CodingValue.schema(description: nil)
              ), __macro_local_1yfMu_(
                name: "y",
                keyPath: \.y,
                schema: __macro_local_1yfMu_.Definition.CodingValue.schema(description: nil)
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

  /// `typeDiscriminated` emits a `codingStyle` member.
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
        static var codingStyle: StructuredCoding.StructuredEnumerationCodingStyleTypeDiscriminated {
          .typeDiscriminated
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
          typealias __macro_local_1xfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
          typealias __macro_local_1yfMu_ = StructuredCoding.StructuredObjectProperty<Self, StructuredCoding.StructuredRequiredObjectPropertyDefinition<Int>>
          typealias Schema = StructuredCoding.StructuredObjectSchema<Self, __macro_local_1xfMu_.Definition, __macro_local_1yfMu_.Definition>
          typealias StructuredObjectProperties = (__macro_local_1xfMu_, __macro_local_1yfMu_)
          static func properties() -> StructuredObjectProperties {
            (__macro_local_1xfMu_(
                name: "x",
                keyPath: \.x,
                schema: __macro_local_1xfMu_.Definition.CodingValue.schema(description: nil)
              ), __macro_local_1yfMu_(
                name: "y",
                keyPath: \.y,
                schema: __macro_local_1yfMu_.Definition.CodingValue.schema(description: nil)
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

      extension Maybe: StructuredCoding.StructuredEnumeration {
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

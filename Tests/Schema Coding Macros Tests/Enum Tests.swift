import Testing

/// Verifies that `@SchemaCodable` lowers enums onto `StructuredEnumeration`,
/// matching the hand-written fixtures in `Tests/Structured Coding Tests`.
@Suite
struct SchemaCodableEnumTests {

  /// Default object-properties style: single-value cases, plus a value-less case
  /// represented by `StructuredEmptyObject`.
  @Test
  func enumObjectProperties() {
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
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

      extension E: SchemaCoding.StructuredEnumeration {
        typealias Cases = (SchemaCoding.StructuredEnumerationCase<Self, String>, SchemaCoding.StructuredEnumerationCase<Self, Int>, SchemaCoding.StructuredEnumerationCase<Self, SchemaCoding.StructuredEmptyObject>)
        static func cases() -> Cases {
          (SchemaCoding.StructuredEnumerationCase(
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
            ), SchemaCoding.StructuredEnumerationCase(
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
            ), SchemaCoding.StructuredEnumerationCase(
              name: "ping",
              accessor: { value in
                guard case .ping = value else {
                  return nil
                }
                return SchemaCoding.StructuredEmptyObject()
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
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
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

      extension T: SchemaCoding.StructuredEnumeration {
        typealias Cases = (SchemaCoding.StructuredEnumerationCase<Self, SchemaCoding.StructuredTuple<Int, String>>, SchemaCoding.StructuredEnumerationCase<Self, SchemaCoding.StructuredTuple<Int, String>>)
        static func cases() -> Cases {
          (SchemaCoding.StructuredEnumerationCase(
              name: "pair",
              accessor: { value in
                guard case .pair(let v0, let v1) = value else {
                  return nil
                }
                return SchemaCoding.StructuredTuple(v0, v1)
              },
              initializer: {
                .pair($0.values.0, $0.values.1)
              }
            ), SchemaCoding.StructuredEnumerationCase(
              name: "mixed",
              accessor: { value in
                guard case .mixed(let v0, let v1) = value else {
                  return nil
                }
                return SchemaCoding.StructuredTuple(v0, v1)
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
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
      enum O {
        case point(x: Int, y: Int)
      }
      """,
      #"""
      enum O {
        case point(x: Int, y: Int)
      }

      extension O: SchemaCoding.StructuredEnumeration {
        typealias Cases = SchemaCoding.StructuredEnumerationCase<Self, __macro_local_5pointfMu_>
        static func cases() -> Cases {
          SchemaCoding.StructuredEnumerationCase(
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
        struct __macro_local_5pointfMu_: SchemaCoding.StructuredObject {
          var x: Int
          var y: Int
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
    assertSchemaCodableExpansion(
      """
      @SchemaCodable(style: .internallyTagged("type"))
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

      extension Event: SchemaCoding.StructuredEnumeration {
        static var codingStyle: SchemaCoding.StructuredEnumerationCodingStyleInternallyTagged {
          SchemaCoding.StructuredEnumerationCodingStyleInternallyTagged(discriminatorPropertyName: "type")
        }
        typealias Cases = (SchemaCoding.StructuredEnumerationCase<Self, Message>, SchemaCoding.StructuredEnumerationCase<Self, __macro_local_4movefMu_>)
        static func cases() -> Cases {
          (SchemaCoding.StructuredEnumerationCase(
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
            ), SchemaCoding.StructuredEnumerationCase(
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
        struct __macro_local_4movefMu_: SchemaCoding.StructuredObject {
          var x: Int
          var y: Int
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
    assertSchemaCodableExpansion(
      """
      @SchemaCodable(style: .typeDiscriminated)
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

      extension Node: SchemaCoding.StructuredEnumeration {
        static var codingStyle: SchemaCoding.StructuredEnumerationCodingStyleTypeDiscriminated {
          .typeDiscriminated
        }
        typealias Cases = (SchemaCoding.StructuredEnumerationCase<Self, String>, SchemaCoding.StructuredEnumerationCase<Self, __macro_local_5pointfMu_>)
        static func cases() -> Cases {
          (SchemaCoding.StructuredEnumerationCase(
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
            ), SchemaCoding.StructuredEnumerationCase(
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
        struct __macro_local_5pointfMu_: SchemaCoding.StructuredObject {
          var x: Int
          var y: Int
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
    assertSchemaCodableExpansion(
      """
      @SchemaCodable
      enum Maybe {
        case maybe(Int?)
      }
      """,
      #"""
      enum Maybe {
        case maybe(Int?)
      }

      extension Maybe: SchemaCoding.StructuredEnumeration {
        typealias Cases = SchemaCoding.StructuredEnumerationCase<Self, Int?>
        static func cases() -> Cases {
          SchemaCoding.StructuredEnumerationCase(
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

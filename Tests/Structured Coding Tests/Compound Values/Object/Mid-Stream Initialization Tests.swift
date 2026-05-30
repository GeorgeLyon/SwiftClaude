import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// `Int` properties have no initial value, so an object containing them cannot
/// be constructed up front. Decoding therefore takes the deferred (Branch B)
/// path in `StructuredObject.decode`, assembling the object mid-stream — the same way
/// `StructuredEnumeration` defers construction until its case is known:
///
/// - while more than one property is still unavailable, each decoded value is
///   buffered through `PreInitializationAccessor`;
/// - when the last unavailable property arrives, `InitializingAccessor`
///   constructs the object mid-stream;
/// - any remaining properties then stream directly into the live object.
///
/// Byte-at-a-time decoding (exercised by `test`) is what forces the
/// construction to land partway through the stream.
@Suite("Mid-Stream Initialization")
struct MidStreamInitializationTests {

  /// Two unavailable scalars then an available tail:
  /// `PreInitializationAccessor` (`a`) → `InitializingAccessor` (`b`,
  /// constructs the object) → in-place streaming (`tail`).
  @Test func initializesAfterLastScalarThenStreamsTail() throws {
    try test(
      #"{"a":1,"b":2,"tail":"hi"}"#,
      decodesAs: DeferredObject(a: 1, b: 2, tail: "hi")
    )
  }

  /// Split the chunk inside `b`'s value, right before the object can be built.
  @Test func initializesAcrossChunkBoundary() throws {
    try test(
      [#"{"a":1,"b":"#, #"2,"tail":"hi"}"#],
      decodesAs: DeferredObject(a: 1, b: 2, tail: "hi")
    )
  }

  /// The available `tail` arrives first and must be buffered while the object
  /// is still uninitialized, then folded in when construction happens.
  @Test func buffersAvailablePropertyBeforeInitialization() throws {
    try test(
      #"{"tail":"hi","a":1,"b":2}"#,
      decodesAs: DeferredObject(a: 1, b: 2, tail: "hi")
    )
  }

  /// A single unavailable property: construction happens on that one value via
  /// `InitializingAccessor`, with no buffering beforehand.
  @Test func singleUnavailablePropertyInitializesMidStream() throws {
    try test(
      #"{"value":7}"#,
      decodesAs: SingleScalarObject(value: 7)
    )
  }

  /// A single unavailable property whose type streams purely by *mutation*
  /// (`String`, not an initialize-once scalar like `Int`): construction must
  /// seed the buffered state so the mutation has a live value to land on.
  @Test func singleUnavailableMutationStreamedPropertyInitializesMidStream() throws {
    try test(
      #"{"name":"Ada"}"#,
      decodesAs: LetStringObject(name: "Ada")
    )
  }

  /// A required deferred property that never arrives must throw, not trap: `{}`
  /// leaves `value` uninitialized, so buffered (Branch B) validation must report
  /// the missing property rather than `fatalError`.
  @Test func missingRequiredDeferredPropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{}"#, decodesAs: SingleScalarObject(value: 0))
    }
  }

  /// An optional deferred property (get-only, no initial value) that is omitted
  /// must still let the object be constructed with `nil`, regardless of key order.
  @Test func omittedOptionalDeferredPropertyDecodes() throws {
    try test(#"{"name":"hi"}"#, decodesAs: ProfileObject(nickname: nil, name: "hi"))
  }

  /// Re-declaring a scalar that was decoded before construction must still be
  /// caught as a duplicate once the object is `.streaming`.
  @Test func duplicateScalarAfterInitializationThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"a":1,"b":2,"tail":"hi","a":3}"#,
        decodesAs: DeferredObject(a: 1, b: 2, tail: "hi")
      )
    }
  }

  /// Re-declaring the property that streamed in-place after construction must
  /// also be caught as a duplicate.
  @Test func duplicateStreamedPropertyAfterInitializationThrows() throws {
    #expect(throws: (any Error).self) {
      try test(
        #"{"a":1,"b":2,"tail":"hi","tail":"x"}"#,
        decodesAs: DeferredObject(a: 1, b: 2, tail: "hi")
      )
    }
  }

  // MARK: - Partial streaming

  /// A deferred object is not observable until it is constructed: before the
  /// last unavailable scalar arrives there is no value to expose.
  @Test func incompleteBeforeConstruction() throws {
    try test(#"{"a":1,"b":"#, decodesAs: DecodingOutcome<DeferredObject>.incomplete)
  }

  /// Once construction happens, the remaining property streams in place and the
  /// object becomes observable mid-stream.
  @Test func partialAfterConstructionStreamsTail() throws {
    try test(
      #"{"a":1,"b":2,"tail":"he"#,
      decodesAs: .partial(DeferredObject(a: 1, b: 2, tail: "h"))
    )
  }
}

// MARK: - Fixtures

/// A single required immutable `let String` property. The get-only key path
/// makes it unavailable up front, yet `String` streams purely by mutation —
/// so construction must seed the buffered state before the mutation arrives.
private struct LetStringObject: StructuredObject, Equatable, Sendable {

  let name: String

  init(name: String) {
    self.name = name
  }

  typealias _NameProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias Properties = _NameProperty
  static func properties() -> Properties {
    _NameProperty(name: "name", keyPath: \.name)
  }

  typealias ObjectDecoderValues = _NameProperty.ObjectDecoderValue
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(name: objectDecoder.values)
  }
}

/// An optional property with no initial value (`let nickname: Int?`, get-only)
/// alongside a mutable `var name`. The get-only key path makes `nickname`
/// unavailable up front, forcing the deferred path; omitting it is valid and the
/// object must still be constructed with `nil`.
private struct ProfileObject: StructuredObject, Equatable, Sendable {

  let nickname: Int?
  var name: String

  init(nickname: Int?, name: String) {
    self.nickname = nickname
    self.name = name
  }

  typealias _NicknameProperty = StructuredObjectProperty<
    Self, StructuredOptionalObjectPropertyDefinition<Int>
  >
  typealias _NameProperty = StructuredObjectProperty<
    Self, StructuredRequiredObjectPropertyDefinition<String>
  >
  typealias Properties = (_NicknameProperty, _NameProperty)
  static func properties() -> Properties {
    (
      _NicknameProperty(name: "nickname", keyPath: \.nickname),
      _NameProperty(name: "name", keyPath: \.name)
    )
  }

  typealias ObjectDecoderValues = (
    _NicknameProperty.ObjectDecoderValue, _NameProperty.ObjectDecoderValue
  )
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>)
    -> sending Self
  {
    Self(nickname: objectDecoder.values.0, name: objectDecoder.values.1)
  }
}

import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// An object-properties enumeration — the default `StructuredEnumeration` coding style — is
/// encoded as a single-property object: the property *name* is the case name and
/// its *value* is that case's associated value (e.g. `{"text":"hello"}`).
/// Decoding reads exactly one property; the name selects the case and the value
/// decodes into the case's associated value. An empty object (no case named), an
/// object carrying more than one property, and an unrecognized case name are all
/// rejected.
///
/// The case is unknown until its property name has been read, so the enumeration
/// cannot be observed before then. Once the case *is* known, the associated
/// value's own decoding semantics take over: a value that has an initial value (a
/// `String`, or a Branch-A `StructuredObject` whose every property defaults) seeds the case
/// immediately — observable mid-stream — while one that does not (an `Int`, or a
/// Branch-B `StructuredObject`) cannot be observed until it is fully constructed.
@Suite("Object-Properties Enumeration")
struct ObjectPropertiesEnumerationTests {

  // MARK: - Happy path

  @Test func decodesPrimitiveCase() throws {
    try test(
      #"{"text":"hello"}"#,
      decodesAs: Value.text("hello")
    )
  }

  @Test func decodesSecondPrimitiveCase() throws {
    try test(
      #"{"count":42}"#,
      decodesAs: Value.count(42)
    )
  }

  /// A case whose associated value is a Branch-A object decodes from a nested
  /// object value.
  @Test func decodesObjectCase() throws {
    try test(
      #"{"message":{"body":"hi"}}"#,
      decodesAs: Value.message(Message(body: "hi"))
    )
  }

  /// A case whose associated value is a Branch-B object (no-initial-value `Int`
  /// properties) decodes through the deferred path.
  @Test func decodesDeferredObjectCase() throws {
    try test(
      #"{"move":{"x":1,"y":2}}"#,
      decodesAs: Value.move(Move(x: 1, y: 2))
    )
  }

  /// A case wrapping an object with no properties of its own decodes from an
  /// empty nested object.
  @Test func decodesEmptyObjectCase() throws {
    try test(
      #"{"ping":{}}"#,
      decodesAs: Value.ping(Ping())
    )
  }

  @Test func decodesWithSurroundingAndInternalWhitespace() throws {
    try test(
      #"{ "text" : "hello" }"#,
      decodesAs: Value.text("hello")
    )
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossCaseName() throws {
    try test(
      [#"{"me"#, #"ssage":{"body":"hi"}}"#],
      decodesAs: Value.message(Message(body: "hi"))
    )
  }

  @Test func chunkedAcrossValue() throws {
    try test(
      [#"{"text":"hel"#, #"lo"}"#],
      decodesAs: Value.text("hello")
    )
  }

  // MARK: - Errors

  /// An empty object names no case.
  @Test func emptyObjectThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{}"#, decodesAs: Value.ping(Ping()))
    }
  }

  @Test func unknownCaseThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"explode":1}"#, decodesAs: Value.count(1))
    }
  }

  /// A second property has no case to belong to; the single-property invariant is
  /// enforced after the first property decodes.
  @Test func moreThanOnePropertyThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"text":"hi","count":1}"#, decodesAs: Value.text("hi"))
    }
  }

  @Test func wrongValueTypeThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"{"count":"not a number"}"#, decodesAs: Value.count(0))
    }
  }

  // MARK: - Partial streaming

  /// Before the property name has finished, the case cannot be selected, so the
  /// enumeration is not observable.
  @Test func incompleteBeforeCaseKnown() throws {
    try test(
      #"{"te"#,
      decodesAs: DecodingOutcome<Value>.incomplete
    )
  }

  /// The instant the case is known, a Branch-A associated value (`String`) is
  /// seeded with its initial value (`""`) — observable before any value
  /// characters arrive.
  @Test func seedsBranchACaseOnceValueBegins() throws {
    try test(
      #"{"text":""#,
      decodesAs: .partial(Value.text(""))
    )
  }

  /// Once associated-value characters arrive the case reflects them (the streamed
  /// string lags by one buffered character).
  @Test func reflectsStreamingAssociatedValue() throws {
    try test(
      #"{"text":"hel"#,
      decodesAs: .partial(Value.text("he"))
    )
  }

  /// A Branch-B primitive (`Int`) has no initial value, so the case is not
  /// observable until the value terminates — and a bare `4` has not been
  /// terminated by a delimiter yet.
  @Test func branchBPrimitiveNotObservableUntilTerminated() throws {
    try test(
      #"{"count":4"#,
      decodesAs: DecodingOutcome<Value>.incomplete
    )
  }

  /// A Branch-A object associated value is seeded the moment the case is known,
  /// even before its own properties stream in.
  @Test func seedsBranchAObjectCase() throws {
    try test(
      #"{"message":{"body":""#,
      decodesAs: .partial(Value.message(Message(body: "")))
    )
  }

  /// A Branch-B object cannot be constructed until its buffered properties are all
  /// present, so the case stays unobservable even with every byte but the brace
  /// that terminates the final property.
  @Test func branchBObjectNotObservableUntilBuilt() throws {
    try test(
      #"{"move":{"x":1,"y":2"#,
      decodesAs: DecodingOutcome<Value>.incomplete
    )
  }

  /// Once the nested object's closing brace terminates its final property, the
  /// Branch-B object is constructed and the case becomes observable — before the
  /// enumeration's own object closes.
  @Test func branchBObjectObservableOnceBuilt() throws {
    try test(
      #"{"move":{"x":1,"y":2}"#,
      decodesAs: .partial(Value.move(Move(x: 1, y: 2)))
    )
  }
}

// MARK: - Fixtures

/// An object-properties enumeration spanning every associated-value shape: a
/// Branch-A primitive (`text`), a Branch-B primitive (`count`), a Branch-A object
/// (`message`), a Branch-B object (`move`), and an empty object (`ping`). It takes
/// the default `StructuredEnumerationCodingStyleObjectProperties`, so no `codingStyle` is
/// declared.
private enum Value: StructuredEnumeration, Equatable, Sendable {

  case text(String)
  case count(Int)
  case message(Message)
  case move(Move)
  case ping(Ping)

  typealias Cases = (
    StructuredEnumerationCase<Self, String>,
    StructuredEnumerationCase<Self, Int>,
    StructuredEnumerationCase<Self, Message>,
    StructuredEnumerationCase<Self, Move>,
    StructuredEnumerationCase<Self, Ping>
  )
  static func cases() -> Cases {
    (
      StructuredEnumerationCase(
        name: "text",
        accessor: { value in
          guard case .text(let associated) = value else { return nil }
          return associated
        },
        initializer: { .text($0) }
      ),
      StructuredEnumerationCase(
        name: "count",
        accessor: { value in
          guard case .count(let associated) = value else { return nil }
          return associated
        },
        initializer: { .count($0) }
      ),
      StructuredEnumerationCase(
        name: "message",
        accessor: { value in
          guard case .message(let associated) = value else { return nil }
          return associated
        },
        initializer: { .message($0) }
      ),
      StructuredEnumerationCase(
        name: "move",
        accessor: { value in
          guard case .move(let associated) = value else { return nil }
          return associated
        },
        initializer: { .move($0) }
      ),
      StructuredEnumerationCase(
        name: "ping",
        accessor: { value in
          guard case .ping(let associated) = value else { return nil }
          return associated
        },
        initializer: { .ping($0) }
      )
    )
  }
}

/// Branch-A associated value: its sole `String` property defaults to `""`, so the
/// case is seeded the moment its name identifies it.
private struct Message: StructuredObject, Equatable, Sendable {

  var body: String

  init(body: String) {
    self.body = body
  }

  typealias Properties = StructuredObjectProperty<Self, StructuredRequiredObjectPropertyDefinition<String>>
  static func properties() -> Properties {
    StructuredObjectProperty(name: "body", keyPath: \.body)
  }

  typealias ObjectDecoderValues = String
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self
  {
    Self(body: objectDecoder.values)
  }
}

/// Branch-B associated value: `Int` properties have no initial value, so the case
/// cannot exist until both are buffered and the object is constructed.
private struct Move: StructuredObject, Equatable, Sendable {

  let x: Int
  let y: Int

  init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }

  typealias Properties = (
    StructuredObjectProperty<Self, StructuredRequiredObjectPropertyDefinition<Int>>,
    StructuredObjectProperty<Self, StructuredRequiredObjectPropertyDefinition<Int>>
  )
  static func properties() -> Properties {
    (
      StructuredObjectProperty(name: "x", keyPath: \.x),
      StructuredObjectProperty(name: "y", keyPath: \.y)
    )
  }

  typealias ObjectDecoderValues = (Int, Int)
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self
  {
    Self(x: objectDecoder.values.0, y: objectDecoder.values.1)
  }
}

/// An associated value with no properties — its object value is `{}`.
private struct Ping: StructuredObject, Equatable, Sendable {

  init() {}

  typealias Properties = ()
  static func properties() -> Properties { () }

  typealias ObjectDecoderValues = ()
  static func decode(from objectDecoder: sending StructuredObjectDecoder<ObjectDecoderValues>) -> sending Self
  {
    Self()
  }
}

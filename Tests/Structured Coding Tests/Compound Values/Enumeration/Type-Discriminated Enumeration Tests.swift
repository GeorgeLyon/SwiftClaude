import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A type-discriminated enumeration is encoded as a bare JSON value with no
/// wrapper: the *kind* of that value (string, number, boolean, object, …) names
/// the case. Decoding peeks the value's kind — which only needs the first
/// non-whitespace character — to identify the case, then decodes the value into
/// that case's associated value. It mirrors the internally-tagged style (peek to
/// pick the case, then iterate the cases until one matches), except the
/// discriminator is the JSON kind itself rather than a property.
///
/// Because the case is unknown until the kind has been read, the enumeration
/// cannot exist until the first character arrives. Once the case *is* known, the
/// associated value's own decoding semantics take over: a `String` (whose initial
/// value is `""`) is seeded the instant the opening quote identifies it, while a
/// Branch-B value — an `Int`, or an object with no-initial-value properties —
/// cannot be observed until it is fully constructed.
@Suite("Type-Discriminated Enumeration")
struct TypeDiscriminatedEnumerationTests {

  // MARK: - Happy path

  @Test func decodesStringCase() throws {
    try test(
      #""hi""#,
      decodesAs: Node.string("hi")
    )
  }

  @Test func decodesNumberCase() throws {
    try test(
      #"42"#,
      decodesAs: Node.integer(42)
    )
  }

  @Test func decodesBooleanCase() throws {
    try test(
      #"true"#,
      decodesAs: Node.boolean(true)
    )
  }

  @Test func decodesObjectCase() throws {
    try test(
      #"{"x":1,"y":2}"#,
      decodesAs: Node.point(Point(x: 1, y: 2))
    )
  }

  @Test func decodesWithSurroundingWhitespace() throws {
    try test(
      #"   "hi"   "#,
      decodesAs: Node.string("hi")
    )
  }

  // MARK: - Chunk boundaries

  /// The kind is settled by the first non-whitespace character, so a chunk of
  /// pure whitespace cannot identify the case yet — the peek resumes once the
  /// value's opening character arrives in a later chunk.
  @Test func chunkedBeforeDiscriminatingCharacter() throws {
    try test(
      [#"   "#, #""hi""#],
      decodesAs: Node.string("hi")
    )
  }

  @Test func chunkedAcrossStringValue() throws {
    try test(
      [#""he"#, #"llo""#],
      decodesAs: Node.string("hello")
    )
  }

  @Test func chunkedAcrossObjectValue() throws {
    try test(
      [#"{"x":1,"#, #""y":2}"#],
      decodesAs: Node.point(Point(x: 1, y: 2))
    )
  }

  // MARK: - Errors

  /// A JSON kind no case claims (`null`) is rejected.
  @Test func unmatchedNullKindThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"null"#, decodesAs: Node.string(""))
    }
  }

  /// Likewise an array, which no case claims.
  @Test func unmatchedArrayKindThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"[1,2]"#, decodesAs: Node.integer(0))
    }
  }

  // MARK: - Partial streaming

  /// Before the first non-whitespace character arrives the kind is unknown, so
  /// the case cannot be selected and the enumeration is not observable.
  @Test func incompleteBeforeKindKnown() throws {
    try test(
      #"   "#,
      decodesAs: DecodingOutcome<Node>.incomplete
    )
  }

  /// The opening quote settles the kind as a string and selects the case, which
  /// seeds its `String` associated value with the initial value (`""`) — observable
  /// before any characters arrive.
  @Test func seedsStringCaseOnceKindKnown() throws {
    try test(
      #"""#,
      decodesAs: .partial(Node.string(""))
    )
  }

  /// Once string characters arrive the case reflects them (the streamed string
  /// lags by one buffered character).
  @Test func reflectsStreamingStringValue() throws {
    try test(
      #""hel"#,
      decodesAs: .partial(Node.string("he"))
    )
  }

  /// A Branch-B `Int` has no initial value, so even though the leading digit has
  /// identified the case, the value is not observable until a delimiter
  /// terminates it — and a bare `4` has none yet.
  @Test func numberNotObservableUntilTerminated() throws {
    try test(
      #"4"#,
      decodesAs: DecodingOutcome<Node>.incomplete
    )
  }

  /// A Branch-B object cannot be constructed until its buffered properties are all
  /// present, so the case stays unobservable even with every byte but the one that
  /// terminates the final property's value.
  @Test func objectNotObservableUntilBuilt() throws {
    try test(
      #"{"x":1,"y":2"#,
      decodesAs: DecodingOutcome<Node>.incomplete
    )
  }

  /// Once a delimiter terminates the final property (here a trailing comma
  /// terminates `2`), the Branch-B object is constructed and the case becomes
  /// observable — before the object itself closes.
  @Test func objectObservableOnceBuilt() throws {
    try test(
      #"{"x":1,"y":2,"#,
      decodesAs: .partial(Node.point(Point(x: 1, y: 2)))
    )
  }
}

// MARK: - Fixtures

/// A type-discriminated enumeration: each case is distinguished purely by the
/// JSON *kind* of its value — a string, a number, a boolean, or an object. The
/// case's `kind` is inferred from its associated value's type.
private enum Node: StructuredEnumeration, Equatable, Sendable {

  case string(String)
  case integer(Int)
  case boolean(Bool)
  case point(Point)

  static var codingStyle: StructuredEnumerationCodingStyleTypeDiscriminated { .typeDiscriminated }

  typealias Cases = (
    StructuredEnumerationCase<Self, String>,
    StructuredEnumerationCase<Self, Int>,
    StructuredEnumerationCase<Self, Bool>,
    StructuredEnumerationCase<Self, Point>
  )
  static func cases() -> Cases {
    (
      StructuredEnumerationCase(
        name: "string",
        accessor: { node in
          guard case .string(let value) = node else { return nil }
          return value
        },
        initializer: { .string($0) }
      ),
      StructuredEnumerationCase(
        name: "integer",
        accessor: { node in
          guard case .integer(let value) = node else { return nil }
          return value
        },
        initializer: { .integer($0) }
      ),
      StructuredEnumerationCase(
        name: "boolean",
        accessor: { node in
          guard case .boolean(let value) = node else { return nil }
          return value
        },
        initializer: { .boolean($0) }
      ),
      StructuredEnumerationCase(
        name: "point",
        accessor: { node in
          guard case .point(let value) = node else { return nil }
          return value
        },
        initializer: { .point($0) }
      )
    )
  }
}

/// A Branch-B object associated value: `Int` properties have no initial value, so
/// the case cannot exist until both are buffered and the object is constructed.
private struct Point: StructuredObject, Equatable, Sendable {

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

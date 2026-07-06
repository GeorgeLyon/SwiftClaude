import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

/// A raw-value enumeration — the style for `RawRepresentable` enums — is encoded
/// as a bare JSON scalar carrying the case's `rawValue`: a `String`-backed enum as
/// a JSON string (`"red"`), an integer-backed enum as a JSON number (`2`). Decoding
/// reads the whole scalar and maps it back to a case with `init(rawValue:)`; a
/// scalar of the wrong JSON kind, or one that names no case, is rejected.
///
/// Because the case is unknown until the entire scalar has been read and matched,
/// a raw-value enumeration has no observable partial value: it stays unobservable
/// until decoding completes. Conforming enums need no boilerplate beyond the raw
/// type — the coding style, `cases()`, and decoding are all supplied by the
/// library.
@Suite("Raw-Value Enumeration")
struct RawValueEnumerationTests {

  // MARK: - String-backed: happy path

  @Test func decodesStringCase() throws {
    try test(#""red""#, decodesAs: Color.red)
  }

  @Test func decodesEachStringCase() throws {
    try test(#""green""#, decodesAs: Color.green)
    try test(#""blue""#, decodesAs: Color.blue)
  }

  /// A case with an explicit raw value distinct from its name decodes from that
  /// raw value, not the case label.
  @Test func decodesCustomStringRawValue() throws {
    try test(#""N""#, decodesAs: Direction.north)
    try test(#""W""#, decodesAs: Direction.west)
  }

  @Test func decodesStringWithSurroundingWhitespace() throws {
    try test(#"   "red"   "#, decodesAs: Color.red)
  }

  // MARK: - Integer-backed: happy path

  @Test func decodesIntegerCase() throws {
    try test(#"2"#, decodesAs: Priority.medium)
  }

  @Test func decodesEachIntegerCase() throws {
    try test(#"1"#, decodesAs: Priority.low)
    try test(#"3"#, decodesAs: Priority.high)
  }

  @Test func decodesMultiDigitIntegerRawValue() throws {
    try test(#"200"#, decodesAs: HTTPStatus.ok)
    try test(#"404"#, decodesAs: HTTPStatus.notFound)
  }

  @Test func decodesIntegerWithSurroundingWhitespace() throws {
    try test(#"  2  "#, decodesAs: Priority.medium)
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossStringRawValue() throws {
    try test([#""gr"#, #"een""#], decodesAs: Color.green)
  }

  /// Pure-whitespace leading chunk cannot identify anything yet; decoding resumes
  /// when the opening quote arrives.
  @Test func chunkedBeforeStringValue() throws {
    try test([#"   "#, #""red""#], decodesAs: Color.red)
  }

  @Test func chunkedAcrossIntegerRawValue() throws {
    try test([#"20"#, #"0"#], decodesAs: HTTPStatus.ok)
  }

  // MARK: - Errors

  /// A string that matches no case's raw value is rejected.
  @Test func unknownStringRawValueThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#""purple""#, decodesAs: Color.red)
    }
  }

  /// An integer that matches no case's raw value is rejected.
  @Test func unknownIntegerRawValueThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"99"#, decodesAs: Priority.low)
    }
  }

  /// A `String`-backed enum rejects a JSON number — the kind does not match.
  @Test func wrongKindForStringEnumThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#"5"#, decodesAs: Color.red)
    }
  }

  /// An integer-backed enum rejects a JSON string — the kind does not match.
  @Test func wrongKindForIntegerEnumThrows() throws {
    #expect(throws: (any Error).self) {
      try test(#""low""#, decodesAs: Priority.low)
    }
  }

  // MARK: - Partial streaming

  /// Before the leading non-whitespace character arrives, nothing identifies a
  /// case, so the enumeration is not observable.
  @Test func incompleteBeforeScalarBegins() throws {
    try test(#"   "#, decodesAs: DecodingOutcome<Color>.incomplete)
  }

  /// A raw-value enum has no initial value and is only built once the whole scalar
  /// is read and matched, so a partial string is not observable.
  @Test func stringNotObservableUntilComplete() throws {
    try test(#""re"#, decodesAs: DecodingOutcome<Color>.incomplete)
  }

  /// Likewise an integer is not observable until a delimiter (or end of input)
  /// terminates it — a bare digit has none yet.
  @Test func integerNotObservableUntilTerminated() throws {
    try test(#"2"#, decodesAs: DecodingOutcome<HTTPStatus>.incomplete)
  }
}

// MARK: - Fixtures

/// A `String`-backed raw-value enumeration whose raw values are its case names.
/// It needs no `StructuredEnumeration` boilerplate: the raw type supplies everything.
private enum Color: String, StructuredEnumeration, Equatable, Sendable {

  case red
  case green
  case blue
}

/// A `String`-backed enumeration with explicit raw values distinct from the case
/// labels, exercising the `rawValue`-to-case mapping.
private enum Direction: String, StructuredEnumeration, Equatable, Sendable {

  case north = "N"
  case south = "S"
  case east = "E"
  case west = "W"
}

/// An integer-backed raw-value enumeration with small, contiguous raw values.
private enum Priority: Int, StructuredEnumeration, Equatable, Sendable {

  case low = 1
  case medium = 2
  case high = 3
}

/// An integer-backed enumeration with multi-digit raw values, exercising number
/// decoding across chunk boundaries.
private enum HTTPStatus: Int, StructuredEnumeration, Equatable, Sendable {

  case ok = 200
  case notFound = 404
}

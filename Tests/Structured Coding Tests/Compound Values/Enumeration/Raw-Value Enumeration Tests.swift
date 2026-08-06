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
/// type and `CaseIterable` (which lets the schema enumerate the raw values) —
/// the coding style, `cases()`, and decoding are all supplied by the library.
@Suite("Raw-Value Enumeration")
struct RawValueEnumerationTests {

  // MARK: - String-backed: happy path

  @Test func decodesStringCase() async throws {
    try await test(#""red""#, decodesAs: Color.red)
  }

  @Test func decodesEachStringCase() async throws {
    try await test(#""green""#, decodesAs: Color.green)
    try await test(#""blue""#, decodesAs: Color.blue)
  }

  /// A case with an explicit raw value distinct from its name decodes from that
  /// raw value, not the case label.
  @Test func decodesCustomStringRawValue() async throws {
    try await test(#""N""#, decodesAs: Direction.north)
    try await test(#""W""#, decodesAs: Direction.west)
  }

  @Test func decodesStringWithSurroundingWhitespace() async throws {
    try await test(#"   "red"   "#, decodesAs: Color.red)
  }

  // MARK: - Integer-backed: happy path

  @Test func decodesIntegerCase() async throws {
    try await test(#"2"#, decodesAs: Priority.medium)
  }

  @Test func decodesEachIntegerCase() async throws {
    try await test(#"1"#, decodesAs: Priority.low)
    try await test(#"3"#, decodesAs: Priority.high)
  }

  @Test func decodesMultiDigitIntegerRawValue() async throws {
    try await test(#"200"#, decodesAs: HTTPStatus.ok)
    try await test(#"404"#, decodesAs: HTTPStatus.notFound)
  }

  @Test func decodesIntegerWithSurroundingWhitespace() async throws {
    try await test(#"  2  "#, decodesAs: Priority.medium)
  }

  // MARK: - Chunk boundaries

  @Test func chunkedAcrossStringRawValue() async throws {
    try await test([#""gr"#, #"een""#], decodesAs: Color.green)
  }

  /// Pure-whitespace leading chunk cannot identify anything yet; decoding resumes
  /// when the opening quote arrives.
  @Test func chunkedBeforeStringValue() async throws {
    try await test([#"   "#, #""red""#], decodesAs: Color.red)
  }

  @Test func chunkedAcrossIntegerRawValue() async throws {
    try await test([#"20"#, #"0"#], decodesAs: HTTPStatus.ok)
  }

  // MARK: - Errors

  /// A string that matches no case's raw value is rejected.
  @Test func unknownStringRawValueThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#""purple""#, decodesAs: Color.red)
    }
  }

  /// An integer that matches no case's raw value is rejected.
  @Test func unknownIntegerRawValueThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"99"#, decodesAs: Priority.low)
    }
  }

  /// A `String`-backed enum rejects a JSON number — the kind does not match.
  @Test func wrongKindForStringEnumThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#"5"#, decodesAs: Color.red)
    }
  }

  /// An integer-backed enum rejects a JSON string — the kind does not match.
  @Test func wrongKindForIntegerEnumThrows() async throws {
    await #expect(throws: (any Error).self) {
      try await test(#""low""#, decodesAs: Priority.low)
    }
  }

  // MARK: - Partial streaming

  /// Before the leading non-whitespace character arrives, nothing identifies a
  /// case, so the enumeration is not observable.
  @Test func incompleteBeforeScalarBegins() async throws {
    try await test(#"   "#, decodesAs: DecodingOutcome<Color>.incomplete)
  }

  /// A raw-value enum has no initial value and is only built once the whole scalar
  /// is read and matched, so a partial string is not observable.
  @Test func stringNotObservableUntilComplete() async throws {
    try await test(#""re"#, decodesAs: DecodingOutcome<Color>.incomplete)
  }

  /// Likewise an integer is not observable until a delimiter (or end of input)
  /// terminates it — a bare digit has none yet.
  @Test func integerNotObservableUntilTerminated() async throws {
    try await test(#"2"#, decodesAs: DecodingOutcome<HTTPStatus>.incomplete)
  }
}

// MARK: - Fixtures

/// A `String`-backed raw-value enumeration whose raw values are its case names.
/// It needs no `StructuredEnumeration` boilerplate: the raw type and
/// `CaseIterable` supply everything.
private enum Color: String, CaseIterable, StructuredEnumeration, Equatable, Sendable {

  case red
  case green
  case blue
}

/// A `String`-backed enumeration with explicit raw values distinct from the case
/// labels, exercising the `rawValue`-to-case mapping.
private enum Direction: String, CaseIterable, StructuredEnumeration, Equatable, Sendable {

  case north = "N"
  case south = "S"
  case east = "E"
  case west = "W"
}

/// An integer-backed raw-value enumeration with small, contiguous raw values.
private enum Priority: Int, CaseIterable, StructuredEnumeration, Equatable, Sendable {

  case low = 1
  case medium = 2
  case high = 3
}

/// An integer-backed enumeration with multi-digit raw values, exercising number
/// decoding across chunk boundaries.
private enum HTTPStatus: Int, CaseIterable, StructuredEnumeration, Equatable, Sendable {

  case ok = 200
  case notFound = 404
}

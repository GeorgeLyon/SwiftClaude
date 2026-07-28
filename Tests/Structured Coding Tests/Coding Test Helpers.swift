import Testing

@testable import JavaScriptObjectNotation
@testable import StructuredCoding

// MARK: - Decoding Outcome

/// Describes the expected state of a partial or complete decoding session.
enum DecodingOutcome<Value> {
  /// The session has not produced an observable value yet (the type cannot
  /// expose a partial value mid-stream).
  case incomplete
  /// The session has produced an observable mid-stream value equal to `value`,
  /// but is not yet complete.
  case partial(Value)
  /// The session has decoded a complete value equal to `value`.
  case complete(Value)
}

// MARK: - Equatable

func test<Value: StructuredDecodable & Equatable>(
  _ jsonFragments: JSONFragments,
  decodesAs value: Value,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try test(
    jsonFragments,
    decodesAs: .complete(value),
    sourceLocation: sourceLocation
  )
}

func test<Value: StructuredDecodable & Equatable>(
  _ jsonFragments: JSONFragments,
  decodesAs outcome: DecodingOutcome<Value>,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try test(
    jsonFragments,
    decodesAs: outcome,
    testEquality: { decoded, expected, sourceLocation in
      #expect(decoded == expected, sourceLocation: sourceLocation)
    },
    sourceLocation: sourceLocation
  )
}

// MARK: - Tuples

func test<Value: StructuredDecodable, each Element: Equatable>(
  _ jsonFragments: JSONFragments,
  decodesAs value: Value,
  decompose: (Value) -> (repeat each Element),
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  try test(
    jsonFragments,
    decodesAs: .complete(value),
    testEquality: { decoded, expected, sourceLocation in
      try testTupleEquality(
        decoded: decoded,
        expected: expected,
        decompose: decompose,
        sourceLocation: sourceLocation
      )
    },
    sourceLocation: sourceLocation
  )
}

private func testTupleEquality<Value, each Element: Equatable>(
  decoded: Value?,
  expected: Value?,
  decompose: (Value) -> (repeat each Element),
  sourceLocation: SourceLocation
) throws {
  switch (decoded, expected) {
  case (let decoded?, let expected?):
    func check<T: Equatable>(_ decoded: T, _ expected: T) throws {
      try #require(decoded == expected, sourceLocation: sourceLocation)
    }
    repeat try check(each decompose(decoded), each decompose(expected))
  case (nil, let expected):
    try #require(expected == nil, sourceLocation: sourceLocation)
  case (let decoded, nil):
    try #require(decoded == nil, sourceLocation: sourceLocation)
  }
}

// MARK: - Decoding

func test<Value: StructuredDecodable>(
  _ jsonFragments: JSONFragments,
  decodesAs outcome: DecodingOutcome<Value>,
  testEquality: (Value?, Value?, SourceLocation) throws -> Void,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let expected: Value?
  let isComplete: Bool
  switch outcome {
  case .incomplete:
    expected = nil
    isComplete = false
  case .partial(let value):
    expected = value
    isComplete = false
  case .complete(let value):
    expected = value
    isComplete = true
  }

  let jsonFragments = jsonFragments.fragments
  let json = jsonFragments.joined()

  func testDecoding(
    _ body: (DecodingSessionStorage<Value>) throws -> Void
  ) throws {
    try decode { (session: DecodingSessionStorage<Value>, provider: any ValueProvider<Value>) in
      try body(session)

      if isComplete {
        session.streamingComplete()
        try #require(session.isDecodingComplete)
        let decoded = try session.value
        try testEquality(decoded, expected, sourceLocation)
      } else {
        try #require(!session.isDecodingComplete)
        let partialValue: Value?
        do {
          partialValue = try provider.value
        } catch JavaScriptObjectNotation.DecodingError.decodingIncomplete {
          partialValue = nil
        }
        try testEquality(partialValue, expected, sourceLocation)
        /// Complete the stream so we don't hang.
        session.streamingComplete()
      }
    }
  }

  /// Test all-at-once decoding
  try testDecoding { session in
    session.stream(json.utf8)
  }

  /// Test explicitly chunked decoding
  try testDecoding { session in
    for fragment in jsonFragments.dropLast() {
      session.stream(fragment.utf8)
      if case .failure(let error)? = session.result {
        throw error
      }
      try #require(!session.isDecodingComplete, sourceLocation: sourceLocation)
    }
    session.stream(jsonFragments.last!.utf8)
  }

  /// Test byte-at-a-time decoding
  try testDecoding { session in
    let bytes = json.utf8
    for byte in bytes.dropLast() {
      session.stream([byte])
      if case .failure(let error)? = session.result {
        throw error
      }
      try #require(!session.isDecodingComplete, sourceLocation: sourceLocation)
    }
    session.stream([bytes.last!])
  }
}

private func decode<Value: StructuredDecodable>(
  _ body: (DecodingSessionStorage<Value>, any ValueProvider<Value>) throws -> Void
) throws {
  var jsonDecoder = JavaScriptObjectNotation.Decoder()
  let box: BoxAccessor<Value>
  if let initialValue = Value.initialValueForDecoding(isMutable: true) {
    box = BoxAccessor(initialValue: initialValue)
  } else {
    box = BoxAccessor()
  }
  let session = jsonDecoder.beginDecoding { stream in
    try await stream.withDecoder { decoder in
      try await Value.decode(from: &decoder, in: StructuredDecodingContext(), using: box)
    }
    try await stream.readTrailingWhitespace()
    return try box.value
  }
  /// The test-facing driver is the session's reference-typed storage rather
  /// than the `~Escapable` session itself so `#expect`/`#require` in test
  /// closures can introspect it (the testing macros require `Copyable`).
  try body(session.storage, box)
}

// MARK: - Value Provider

/// Exposes the value being decoded, whether that is the final value produced by
/// a decoding session or the in-progress value held by a `BoxAccessor`.
private protocol ValueProvider<Value> {
  associatedtype Value
  var value: Value { get throws }
}

private final class BoxAccessor<Value>: StructuredAccessor, ValueProvider {

  init(initialValue: Value) {
    stored = initialValue
  }

  /// Starts empty: the value is initialized mid-stream by the decoder.
  init() {
    stored = nil
  }

  var value: Value {
    get throws {
      guard let stored else {
        throw JavaScriptObjectNotation.DecodingError.decodingIncomplete
      }
      return stored
    }
  }

  var isMutable: Bool { true }

  func initializeValue(to value: consuming sending Value) async throws {
    stored = value
  }

  func accessValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (borrowing Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    guard let stored else { throw AccessorError.uninitializedValue }
    return try await apply(stored, delta)
  }

  func mutateValue<Delta, T>(
    applying delta: sending Delta,
    apply: @Sendable (inout Value, sending Delta) async throws -> sending T
  ) async throws -> sending T {
    guard var value = stored else { throw AccessorError.uninitializedValue }
    defer { stored = value }
    return try await apply(&value, delta)
  }

  private var stored: Value?
}

// MARK: - Encoding

func test<Value: StructuredEncodable>(
  _ value: Value,
  encodesAs json: String,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  var encoder = StructuredEncoder()
  try value.encode(to: &encoder)
  #expect(encoder.stringValue == json, sourceLocation: sourceLocation)
}

// MARK: - JSON Fragments

struct JSONFragments: ExpressibleByStringInterpolation, ExpressibleByArrayLiteral {

  init(stringLiteral value: String) {
    fragments = [value]
  }

  init(stringInterpolation: DefaultStringInterpolation) {
    fragments = [String(stringInterpolation: stringInterpolation)]
  }

  init(arrayLiteral elements: String...) {
    fragments = elements
  }

  let fragments: [String]
}

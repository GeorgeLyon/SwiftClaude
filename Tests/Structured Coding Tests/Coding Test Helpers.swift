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
) async throws {
  try await test(
    jsonFragments,
    decodesAs: .complete(value),
    sourceLocation: sourceLocation
  )
}

func test<Value: StructuredDecodable & Equatable>(
  _ jsonFragments: JSONFragments,
  decodesAs outcome: DecodingOutcome<Value>,
  sourceLocation: SourceLocation = #_sourceLocation
) async throws {
  try await test(
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
) async throws {
  try await test(
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
) async throws {
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
    _ body: (DecodingSession<Value>) throws -> Void
  ) throws {
    try decode { (session: DecodingSession<Value>, provider: any ValueProvider<Value>) in
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

  /// Test the same streaming shapes through the actor-based `Decoder`, which
  /// pulls chunks from an async sequence. It exposes no session to observe
  /// mid-stream state, so only complete outcomes can be verified this way
  /// (an outcome that is incomplete mid-stream, like a bare `4`, may still
  /// decode successfully once the stream ends).
  if isComplete {
    for chunks in [
      [Array(json.utf8)],
      jsonFragments.map { Array($0.utf8) },
      Array(json.utf8).map { [$0] },
    ] {
      let decoded: Value = try await decode(chunks: chunks)
      try testEquality(decoded, expected, sourceLocation)
    }
  }
}

private func decode<Value: StructuredDecodable>(
  chunks: [[UInt8]]
) async throws -> Value {
  let (bytes, continuation) = AsyncStream<[UInt8]>.makeStream()
  for chunk in chunks {
    continuation.yield(chunk)
  }
  continuation.finish()

  let decoder = JavaScriptObjectNotation.Decoder()
  return try await decoder.decode(from: bytes) { stream in
    let box: BoxAccessor<Value> = makeBoxAccessor()
    try await stream.withStructuredDecodingStream { stream in
      try await Value.decode(from: &stream, in: StructuredDecodingContext(), using: box)
    }
    try await stream.readTrailingWhitespace()
    return try box.value
  }
}

private func decode<Value: StructuredDecodable>(
  _ body: (DecodingSession<Value>, any ValueProvider<Value>) throws -> Void
) throws {
  let decoder = SynchronousDecoder()
  let box: BoxAccessor<Value> = makeBoxAccessor()
  let session = decoder.startDecoding { stream in
    try await stream.withStructuredDecodingStream { stream in
      try await Value.decode(from: &stream, in: StructuredDecodingContext(), using: box)
    }
    try await stream.readTrailingWhitespace()
    return try box.value
  }
  try body(session, box)
}

private func makeBoxAccessor<Value: StructuredDecodable>() -> BoxAccessor<Value> {
  if let initialValue = Value.initialValueForDecoding(isMutable: true) {
    BoxAccessor(initialValue: initialValue)
  } else {
    BoxAccessor()
  }
}

// MARK: - Value Provider

/// Exposes the value being decoded, whether that is the final value produced by
/// a `DecodingSession` or the in-progress value held by a `BoxAccessor`.
private protocol ValueProvider<Value> {
  associatedtype Value
  var value: Value { get throws }
}

extension DecodingSession: ValueProvider {}

/// `@unchecked Sendable` because access is externally synchronized: the
/// decoder (the synchronous pump, or the actor-based `Decoder`'s operation)
/// writes while decoding, and the test driver only reads between pushes or
/// after the decode completes.
private final class BoxAccessor<Value>: StructuredAccessor, ValueProvider, @unchecked Sendable {

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

/// Async for uniformity with the decoding helpers, so every `test` call site
/// is `try await`.
func test<Value: StructuredEncodable>(
  _ value: Value,
  encodesAs json: String,
  sourceLocation: SourceLocation = #_sourceLocation
) async throws {
  var stream = StructuredEncodingStream()
  try value.encode(to: &stream)
  #expect(stream.stringValue == json, sourceLocation: sourceLocation)
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

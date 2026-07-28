import Testing

@testable import JavaScriptObjectNotation

@Suite("Decoder")
struct DecoderTests {

  /// A decoder is reusable across sequential sessions: each session's
  /// `DecodingStream` deinit resets the shared stream state when the session
  /// ends, and the next session starts fresh.
  @Test
  func reusedAcrossSequentialSessions() throws {
    var decoder = JavaScriptObjectNotation.Decoder()

    var first = decoder.beginDecoding { try await $0.decodeBoolean() }
    first.stream(Array("true".utf8))
    let firstComplete = first.isDecodingComplete
    #expect(firstComplete)
    let firstValue = try first.finish()
    #expect(firstValue == true)

    var second = decoder.beginDecoding { try await $0.decodeBoolean() }
    second.stream(Array("tr".utf8))
    second.stream(Array("ue".utf8))
    let secondValue = try second.finish()
    #expect(secondValue == true)
  }

  /// A failed decode must not poison the decoder for the next session.
  @Test
  func reusedAfterFailedDecode() throws {
    var decoder = JavaScriptObjectNotation.Decoder()

    do {
      var first = decoder.beginDecoding { try await $0.decodeBoolean() }
      first.stream(Array("nope".utf8))
      let firstComplete = first.isDecodingComplete
      #expect(firstComplete)
      var thrown: (any Error)?
      do {
        _ = try first.finish()
      } catch {
        thrown = error
      }
      #expect(thrown != nil)
    }

    var second = decoder.beginDecoding { try await $0.decodeBoolean() }
    second.stream(Array("false".utf8))
    let secondValue = try second.finish()
    #expect(secondValue == false)
  }

  /// A suspended decode forms a strong reference cycle (stream state → stored
  /// continuation → task → session storage). Abandoning an in-flight session
  /// without finishing must not leak: dropping the session completes its
  /// stream, the suspended decode unwinds, and the storage is released.
  @Test
  func abandonedInFlightSessionIsDeallocated() {
    weak var weakStorage: DecodingSessionStorage<String>?
    do {
      var decoder = JavaScriptObjectNotation.Decoder()
      var session = decoder.beginDecoding { try await $0.decodeString() }
      session.stream(Array(#""partial"#.utf8))  // no closing quote: suspends, stores a continuation
      weakStorage = session.storage
    }
    #expect(weakStorage == nil, "abandoned in-flight decoding session should be deallocated")
  }

  /// The decode job must be pumpable immediately even when the decoder is
  /// driven from an actor-isolated context: if the decode task inherited the
  /// caller's actor context instead of being detached onto the engine, the
  /// pump would stall and this synchronous decode would fail.
  @Test @MainActor
  func decodesSynchronouslyFromActorIsolatedContext() throws {
    var decoder = JavaScriptObjectNotation.Decoder()
    let value = try decoder.decode(from: Array("true".utf8), with: decodeBooleanOperation)
    #expect(value == true)
  }

  private nonisolated func decodeBooleanOperation(
    _ stream: inout DecodingStream
  ) async throws -> Bool {
    try await stream.decodeBoolean()
  }

  /// An actor-isolated operation cannot run on the decoder's pump — it is
  /// scheduled onto its actor instead, which can never run it while the
  /// caller is inside the synchronous decode. This must surface as the
  /// descriptive `decodingStalled` error, not a bare `decodingIncomplete`.
  @Test @MainActor
  func actorIsolatedOperationFailsWithStalledError() {
    var decoder = JavaScriptObjectNotation.Decoder()
    var thrown: DecodingError?
    do {
      _ = try decoder.decode(from: Array("true".utf8), with: Self.mainActorOperation)
    } catch let error as DecodingError {
      thrown = error
    } catch {}
    guard case .decodingStalled = thrown else {
      Issue.record("expected decodingStalled, got \(String(describing: thrown))")
      return
    }
  }

  @MainActor
  private static func mainActorOperation(
    _ stream: inout DecodingStream
  ) async throws -> Bool {
    try await stream.decodeBoolean()
  }

  /// The pull-based variant decodes by pumping each chunk as it arrives.
  @Test
  func decodesFromAsyncByteStream() async throws {
    let stream = AsyncStream<[UInt8]> { continuation in
      for chunk in ["  tr", "ue", " "] {
        continuation.yield(Array(chunk.utf8))
      }
      continuation.finish()
    }
    var decoder = JavaScriptObjectNotation.Decoder()
    let value = try await decoder.decode(from: stream) { stream in
      let value = try await stream.decodeBoolean()
      try await stream.readTrailingWhitespace()
      return value
    }
    #expect(value == true)
  }

}

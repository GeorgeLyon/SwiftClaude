import Testing

@testable import JavaScriptObjectNotation

@Suite("Incremental Decoder")
struct IncrementalDecoderTests {

  /// After one decode finishes and its operation's `DecodingStream` deinits
  /// (resetting the shared state), further `stream(_:)` / `streamingComplete()`
  /// calls on the now-finished session must not poison the state for the
  /// next session.
  @Test
  func reusedAcrossSessionsAfterStrayProducerCalls() throws {
    let decoder = IncrementalDecoder()

    let first = decoder.startDecoding { try await $0.decodeBoolean() }
    first.stream(Array("true".utf8))
    #expect(first.isDecodingComplete)
    _ = try first.value
    // Stray producer calls after the decode finished must be ignored,
    // not forwarded onto the (now-reset) shared stream state.
    first.streamingComplete()
    first.stream(Array("garbage".utf8))

    let second = decoder.startDecoding { try await $0.decodeBoolean() }
    second.stream(Array("tr".utf8))
    second.stream(Array("ue".utf8))
    second.streamingComplete()
    #expect(try second.value == true)
  }

  /// Producer calls on a session whose decode failed are also ignored.
  @Test
  func reusedAfterFailedDecode() throws {
    let decoder = IncrementalDecoder()

    let first = decoder.startDecoding { try await $0.decodeBoolean() }
    first.stream(Array("nope".utf8))
    first.streamingComplete()
    #expect(first.isDecodingComplete)
    #expect(throws: (any Error).self) { try first.value }
    // Stray calls after a failed decode must also be no-ops.
    first.stream(Array("more".utf8))
    first.streamingComplete()

    let second = decoder.startDecoding { try await $0.decodeBoolean() }
    second.stream(Array("false".utf8))
    second.streamingComplete()
    #expect(try second.value == false)
  }

  /// A suspended decode forms a strong reference cycle (stream state → stored
  /// continuation → task → session). Abandoning an in-flight session without
  /// calling `streamingComplete()` must not leak the session: when the decoder
  /// is deallocated, the stored continuation is resumed with a cancellation
  /// error so the suspended decode unwinds and the session is released.
  @Test
  func abandonedInFlightSessionIsDeallocated() {
    weak var weakSession: DecodingSession<String>?
    do {
      let decoder = IncrementalDecoder()
      let session = decoder.startDecoding { try await $0.decodeString() }
      session.stream(Array(#""partial"#.utf8))  // no closing quote: suspends, stores a continuation
      weakSession = session
      withExtendedLifetime(decoder) {}
    }
    #expect(weakSession == nil, "abandoned in-flight decoding session should be deallocated")
  }

}

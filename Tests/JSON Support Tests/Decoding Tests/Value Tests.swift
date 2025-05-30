import Foundation
import Testing

@testable import JSONSupport

@Suite("Value Tests")
private struct ValueTests {

  @Test
  func numberValuesTest() async throws {
    /// Integer
    do {
      var stream = JSON.DecodingStream()
      stream.push("42")
      stream.finish()

      try stream.withDecodeValueResult { result, decodedSubstring in
        #expect(result.isDecoded)
        #expect(decodedSubstring == "42")
      }
    }
  }

}

// MARK: - Support

extension JSON.DecodingStream {

  fileprivate mutating func withDecodeValueResult(
    _ checkpoint: JSON.DecodingStream.Checkpoint? = nil,
    _ body: (JSON.DecodingResult<Void>, Substring) -> Void
  ) throws {
    var state = JSON.ValueDecodingState()
    try withDecodeValueResult(checkpoint, state: &state, body)
  }

  fileprivate mutating func withDecodeValueResult(
    _ checkpoint: JSON.DecodingStream.Checkpoint? = nil,
    state: inout JSON.ValueDecodingState,
    _ body: (JSON.DecodingResult<Void>, Substring) -> Void
  ) throws {
    let checkpoint = checkpoint ?? createCheckpoint()
    let result = try decodeValue(&state)
    body(result, substringDecoded(since: checkpoint))
  }

}

extension JSON.DecodingResult {
  var needsMoreData: Bool {
    switch self {
    case .needsMoreData:
      return true
    case .decoded:
      return false
    }
  }
  var isDecoded: Bool {
    switch self {
    case .needsMoreData:
      return false
    case .decoded:
      return true
    }
  }
}

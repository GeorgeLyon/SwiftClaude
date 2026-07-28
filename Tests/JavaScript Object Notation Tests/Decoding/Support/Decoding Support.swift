@testable import JavaScriptObjectNotation

func decode<T>(
  _ type: T.Type = T.self,
  readTrailingWhitespace: Bool = true,
  _ operation: @escaping (inout DecodingStream) async throws -> T,
  stream: (DecodingSessionStorage<T>) throws -> Void,
  onComplete: ((Result<T, Error>) throws -> Void)? = nil
) throws {
  var decoder = JavaScriptObjectNotation.Decoder()
  var session = decoder.beginDecoding { stream in
    let value = try await operation(&stream)
    if onComplete != nil, readTrailingWhitespace {
      try await stream.readTrailingWhitespace()
    }
    return value
  }
  /// The test-facing driver is the session's reference-typed storage rather
  /// than the `~Escapable` session itself so `#expect`/`#require` in test
  /// closures can introspect it (the testing macros require `Copyable`).
  try stream(session.storage)
  session.streamingComplete()
  if let onComplete {
    guard let result = session.result else {
      throw DecodingError.decodingIncomplete
    }
    try onComplete(result)
  }
}

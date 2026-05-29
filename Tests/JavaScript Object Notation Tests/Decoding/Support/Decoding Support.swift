@testable import JavaScriptObjectNotation

func decode<T>(
  _ type: T.Type = T.self,
  readTrailingWhitespace: Bool = true,
  _ operation: @escaping (inout DecodingStream) async throws -> T,
  stream: (borrowing DecodingSession<T>) throws -> Void,
  onComplete: ((Result<T, Error>) throws -> Void)? = nil
) throws {
  let decoder = IncrementalDecoder()
  let session = decoder.startDecoding { stream in
    let value = try await operation(&stream)
    if onComplete != nil, readTrailingWhitespace {
      try await stream.readTrailingWhitespace()
    }
    return value
  }
  do {
    try stream(session)
    session.streamingComplete()
    if let onComplete {
      guard let result = session.result else {
        throw DecodingError.decodingIncomplete
      }
      try onComplete(result)
    }
  }
}

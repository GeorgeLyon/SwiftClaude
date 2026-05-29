import Testing

@testable import JavaScriptObjectNotation

@Suite
struct NullDecoding {

  @Test
  func null() throws {
    try decode { stream in
      try await stream.decodeNull()
    } stream: { session in
      session.stream("   nu".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("ll".utf8)
    } onComplete: { result in
      try result.get()
    }
  }

}

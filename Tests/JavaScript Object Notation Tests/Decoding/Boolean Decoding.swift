import Testing

@testable import JavaScriptObjectNotation

@Suite
struct BooleanDecoding {

  @Test
  func trueLiteral() async throws {
    try decode { stream in
      try await stream.decodeBoolean()
    } stream: { session in
      session.stream("     tr".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("ue ".utf8)
    } onComplete: { result in
      try #require(result.get() == true)
    }
  }

  @Test
  func falseLiteral() throws {
    try decode { stream in
      try await stream.decodeBoolean()
    } stream: { session in
      session.stream(" fa".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("l".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("se".utf8)
    } onComplete: { result in
      try #require(result.get() == false)
    }
  }

}

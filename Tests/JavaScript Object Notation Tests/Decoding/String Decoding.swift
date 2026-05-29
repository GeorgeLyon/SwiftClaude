import Testing

@testable import JavaScriptObjectNotation

@Suite
struct StringDecoding {

  @Test
  func emptyString() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("\"\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "")
    }
  }

  @Test
  func simpleString() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("\"hello\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "hello")
    }
  }

  @Test
  func leadingWhitespace() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("   \"hello\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "hello")
    }
  }

  @Test
  func escapeSequences() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""\n\t\r\\\"\/\b\f""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "\n\t\r\\\"/\u{0008}\u{000C}")
    }
  }

  @Test
  func unicodeEscape() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""\u0041""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "A")
    }
  }

  @Test
  func unicodeEscapeNonASCII() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""\u00E9""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "\u{00E9}")
    }
  }

  @Test
  func unicodeEscapeCJK() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""\u4E16\u754C""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "世界")
    }
  }

  @Test
  func surrogatePair() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""\uD83D\uDE00""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "😀")
    }
  }

  @Test
  func streamedInChunks() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("\"hel".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("lo\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "hello")
    }
  }

  @Test
  func escapeSplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("\"a\\".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("nb\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "a\nb")
    }
  }

  @Test
  func unicodeEscapeSplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""\u00"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#"41""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "A")
    }
  }

  @Test
  func surrogatePairSplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""\uD83D"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#"\uDE00""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "😀")
    }
  }

  @Test
  func multibyteUTF8() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("\"café\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "café")
    }
  }

  @Test
  func stringWithSpaces() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("\"hello world\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "hello world")
    }
  }

  @Test
  func forwardSlashEscape() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream(#""a\/b""#.utf8)
    } onComplete: { result in
      try #require(result.get() == "a/b")
    }
  }

  @Test
  func manyChunks() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      session.stream("  ".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("\"".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("a".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("b".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("c".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("\"".utf8)
    } onComplete: { result in
      try #require(result.get() == "abc")
    }
  }

  @Test
  func emojiByteByByte() throws {
    try decode { stream in
      try await stream.decodeString()
    } stream: { session in
      let bytes = Array("\"emoji: 🎉\"".utf8)
      for (index, byte) in bytes.enumerated() {
        session.stream(CollectionOfOne(byte))
        if index < bytes.count - 1 {
          try #require(!session.isDecodingComplete)
        }
      }
    } onComplete: { result in
      try #require(result.get() == "emoji: 🎉")
    }
  }

}
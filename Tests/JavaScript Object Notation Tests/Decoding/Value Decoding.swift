import Testing

@testable import JavaScriptObjectNotation

@Suite
struct ValueDecoding {

  // MARK: - peekValueKind

  @Test
  func peekNull() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("null".utf8)
      try #require(session.result?.get() == .null)
    }
  }

  @Test
  func peekTrue() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("true".utf8)
      try #require(session.result?.get() == .boolean)
    }
  }

  @Test
  func peekFalse() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("false".utf8)
      try #require(session.result?.get() == .boolean)
    }
  }

  @Test
  func peekPositiveNumber() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("42".utf8)
      try #require(session.result?.get() == .number)
    }
  }

  @Test
  func peekNegativeNumber() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("-1".utf8)
      try #require(session.result?.get() == .number)
    }
  }

  @Test
  func peekString() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream(#""hello""#.utf8)
      try #require(session.result?.get() == .string)
    }
  }

  @Test
  func peekArray() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("[1, 2]".utf8)
      try #require(session.result?.get() == .array)
    }
  }

  @Test
  func peekObject() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream(#"{"a": 1}"#.utf8)
      try #require(session.result?.get() == .object)
    }
  }

  @Test
  func peekWithLeadingWhitespace() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("   42".utf8)
      try #require(session.result?.get() == .number)
    }
  }

  @Test
  func peekWithWhitespaceAcrossChunks() throws {
    try decode(readTrailingWhitespace: false) { stream in
      try await stream.peekValueKind()
    } stream: { session in
      session.stream("   ".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("true".utf8)
      try #require(session.result?.get() == .boolean)
    }
  }

  // MARK: - decodeValue

  @Test
  func decodeNull() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("null".utf8)
    }
  }

  @Test
  func decodeTrue() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("true".utf8)
    }
  }

  @Test
  func decodeFalse() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("false".utf8)
    }
  }

  @Test
  func decodeNumber() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("42".utf8)
    }
  }

  @Test
  func decodeNegativeNumber() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("-3.14".utf8)
    }
  }

  @Test
  func decodeString() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream(#""hello""#.utf8)
    }
  }

  @Test
  func decodeEmptyArray() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("[]".utf8)
    }
  }

  @Test
  func decodeArrayWithElements() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("[1, 2, 3]".utf8)
    }
  }

  @Test
  func decodeEmptyObject() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("{}".utf8)
    }
  }

  @Test
  func decodeObjectWithProperties() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream(#"{"a": 1, "b": 2}"#.utf8)
    }
  }

  @Test
  func decodeNestedStructure() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream(#"{"a": [1, true, null], "b": {"c": "hello"}}"#.utf8)
    }
  }

  @Test
  func decodeDeeplyNested() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream(#"[[["nested"]]]"#.utf8)
    }
  }

  @Test
  func decodeMixedArray() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream(#"[1, "two", true, null, [3], {"four": 4}]"#.utf8)
    }
  }

  @Test
  func decodeWithLeadingWhitespace() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("   null".utf8)
    }
  }

  @Test
  func decodeStreamedInChunks() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream(#"{"a":"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#" [1, 2]}"#.utf8)
    }
  }

  @Test
  func decodeSplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeValue()
    } stream: { session in
      session.stream("[".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("1".utf8)
      try #require(!session.isDecodingComplete)
      session.stream(",".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("2".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("]".utf8)
    }
  }

}

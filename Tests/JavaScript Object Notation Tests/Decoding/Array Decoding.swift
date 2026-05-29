import Testing

@testable import JavaScriptObjectNotation

@Suite
struct ArrayDecoding {

  @Test
  func emptyArray() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("[]".utf8)
    } onComplete: { result in
      try #require(result.get() == [Int]())
    }
  }

  @Test
  func emptyArrayWithWhitespace() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("[  ]".utf8)
    } onComplete: { result in
      try #require(result.get() == [Int]())
    }
  }

  @Test
  func singleElement() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("[42]".utf8)
    } onComplete: { result in
      try #require(result.get() == [42])
    }
  }

  @Test
  func multipleElements() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("[1, 2, 3]".utf8)
    } onComplete: { result in
      try #require(result.get() == [1, 2, 3])
    }
  }

  @Test
  func leadingWhitespace() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("  [1, 2]".utf8)
    } onComplete: { result in
      try #require(result.get() == [1, 2])
    }
  }

  @Test
  func whitespaceAroundElements() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("[ 1 , 2 , 3 ]".utf8)
    } onComplete: { result in
      try #require(result.get() == [1, 2, 3])
    }
  }

  @Test
  func arrayOfStrings() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeString()
      }
    } stream: { session in
      session.stream(#"["hello", "world"]"#.utf8)
    } onComplete: { result in
      try #require(result.get() == ["hello", "world"])
    }
  }

  @Test
  func nestedArrays() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeArrayElements { stream in
          try await stream.decodeNumber().decode(as: Int.self)
        }
      }
    } stream: { session in
      session.stream("[[1, 2], [3]]".utf8)
    } onComplete: { result in
      try #require(result.get() == [[1, 2], [3]])
    }
  }

  @Test
  func streamedInChunks() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("[1,".utf8)
      try #require(!session.isDecodingComplete)
      session.stream(" 2, 3]".utf8)
    } onComplete: { result in
      try #require(result.get() == [1, 2, 3])
    }
  }

  @Test
  func elementSplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeString()
      }
    } stream: { session in
      session.stream(#"["hel"#.utf8)
      try #require(!session.isDecodingComplete)
      session.stream(#"lo"]"#.utf8)
    } onComplete: { result in
      try #require(result.get() == ["hello"])
    }
  }

  @Test
  func bracketsSplitAcrossChunks() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream("[".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("1, 2".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("]".utf8)
    } onComplete: { result in
      try #require(result.get() == [1, 2])
    }
  }

  @Test
  func manyChunks() throws {
    try decode { stream in
      try await stream.decodeArrayElements { stream in
        try await stream.decodeNumber().decode(as: Int.self)
      }
    } stream: { session in
      session.stream(" ".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("[".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("1".utf8)
      try #require(!session.isDecodingComplete)
      session.stream(",".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("2".utf8)
      try #require(!session.isDecodingComplete)
      session.stream("]".utf8)
    } onComplete: { result in
      try #require(result.get() == [1, 2])
    }
  }

}
